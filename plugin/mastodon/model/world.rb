# coding: utf-8
module Plugin::Mastodon
  class World < Diva::Model
    extend Memoist

    register :mastodon, name: Plugin[:mastodon]._('Mastodon')

    field.string :id, required: true
    field.string :slug, required: true
    alias :name :slug
    field.string :domain, required: true
    field.string :access_token, required: true
    field.has :account, Account, required: true

    alias :user_obj :account

    @@lists = Hash.new
    @@followings = Hash.new
    @@followers = Hash.new
    @@blocks = Hash.new

    memoize def path
      "/#{account.acct.split('@').reverse.join('/')}"
    end

    def inspect
      "mastodon-world(#{account.acct})"
    end

    def icon
      account.icon
    end

    def title
      account.title
    end

    def server
      @server ||= Plugin::Mastodon::Instance.load(domain)
    end

    def sse
      Plugin::Mastodon::SSEAuthorizedType.new(world: self)
    end

    def rest
      Plugin::Mastodon::RestAuthorizedType.new(world: self)
    end

    def datasource_slug(type, n = nil)
      case type
      when :home
        # ホームTL
        "mastodon-#{account.acct}-home".to_sym
      when :direct
        # DM TL
        "mastodon-#{account.acct}-direct".to_sym
      when :list
        # リストTL
        "mastodon-#{account.acct}-list-#{n}".to_sym
      else
        "mastodon-#{account.acct}-#{type.to_s}".to_sym
      end
    end

    def get_lists
      Delayer::Deferred.new do
        if @@lists[uri.to_s]
          @@lists[uri.to_s]  # TODO: キャッシュはAPIクラスで行いたい
        else
          API.call(:get, domain, '/api/v1/lists', access_token).next do |lists|
            @@lists[uri.to_s] = lists.value
          end
        end
      end
    end

    def update_mutes!
      params = { limit: 80 }
      since_id = nil
      Status.clear_mutes
      while mutes = Plugin::Mastodon::API.call!(:get, domain, '/api/v1/mutes', access_token, **params)
        Status.add_mutes(mutes.value)
        return unless mutes.header && mutes.header[:prev]
        url = mutes.header[:prev]
        params = URI.decode_www_form(url.query).to_h.map{|k,v| [k.to_sym, v] }.to_h
        return if params[:since_id].to_i == since_id
        since_id = params[:since_id].to_i

        sleep 1
      end
    end

    # 投稿する
    # opts[:in_reply_to_id] Integer 返信先Statusの（ローカル）ID
    # opts[:media_ids] Array 添付画像IDの配列（最大4）
    # opts[:sensitive] True | False NSFWフラグの明示的な指定
    # opts[:spoiler_text] String ContentWarning用のコメント
    # opts[:visibility] String 公開範囲。 "direct", "private", "unlisted", "public" のいずれか。
    def post(to: nil, message:, **params)
      params[:status] = message
      if to ||= params[:replyto]
        API.get_local_status_id(self, to).next{ |status_id|
          API.call(:post, domain, '/api/v1/statuses', access_token, in_reply_to_id: status_id, **params)
        }.terminate(Plugin[:mastodon]._('返信先Statusが%{domain}内に見つかりませんでした：%{url}') % {domain: domain, url: to.url})
      else
        API.call(:post, domain, '/api/v1/statuses', access_token, **params)
      end
    end

    # _status_ をboostする。
    # ==== Args
    # [status] boostするtoot
    # ==== Return
    # [Delayer::Deferred] boost完了したら、新たに作られたstatusを返すDeferred
    def reblog(status)
      Plugin::Mastodon::API.get_local_status_id(self, status.actual_status).next{ |status_id|
        new_status_hash = +Plugin::Mastodon::API.call(:post, domain, '/api/v1/statuses/' + status_id.to_s + '/reblog', access_token)
        new_status = Plugin::Mastodon::Status.build(server, new_status_hash.value)
        Plugin.call(:share, new_status.user, status)
        new_status
      }
    end

    def get_accounts!(type)
      promise = Delayer::Deferred.new(true)
      Thread.new do
        accounts = []
        params = {
          limit: 80
        }
        API.all_with_world!(self, :get, "/api/v1/accounts/#{account.id}/#{type}", **params) do |hash|
          accounts << hash
        end
        promise.call(accounts.map {|hash| Account.new hash })
      rescue Exception => e
        Plugin::Mastodon::Util.ppf e if Mopt.error_level >= 2 # warn
        promise.fail("failed to get #{type}")
      end
      promise
    end

    def following?(acct)
      acct = acct.acct if acct.is_a?(Account)
      @@followings[uri.to_s].to_a.any? { |account| account.acct == acct }
    end

    def followings(cache: true, **opts)
      promise = Delayer::Deferred.new(true)
      Thread.new do
        next promise.call(@@followings[uri.to_s]) if cache && @@followings[uri.to_s]
        get_accounts!('following').next do |accounts|
          @@followings[uri.to_s] = accounts
          promise.call(accounts)
        end
      end
      promise
    end

    def followers(cache: true, **opts)
      promise = Delayer::Deferred.new(true)
      Thread.new do
        next promise.call(@@followers[uri.to_s]) if cache && @@followers[uri.to_s]
        get_accounts!('followers').next do |accounts|
          @@followers[uri.to_s] = accounts
          promise.call(accounts)
        end
      end
      promise
    end

    def blocks
      promise = Delayer::Deferred.new(true)
      Thread.new do
        accounts = []
        params = {
          limit: 80
        }
        API.all_with_world!(self, :get, "/api/v1/blocks", **params) do |hash|
          accounts << hash
        end
        @@blocks[uri.to_s] = accounts.map { |hash| Account.new hash }
        promise.call(@@blocks[uri.to_s])
      rescue Exception => e
        Plugin::Mastodon::Util.ppf e if Mopt.error_level >= 2 # warn
        promise.fail('failed to get blocks')
      end
      promise
    end

    def block?(acct)
      @@blocks[uri.to_s].to_a.any? { |acc| acc.acct == acct }
    end

    def account_action(account, type)
      Plugin::Mastodon::API.get_local_account_id(self, account).next{ |account_id|
        Plugin::Mastodon::API.call(:post, domain, "/api/v1/accounts/#{account_id}/#{type}", access_token)
      }
    end

    def follow(account)
      account_action(account, "follow").next{ |ret|
        @@followings[uri.to_s] = [*@@followings[uri.to_s], account]
        followings(cache: false)
        ret
      }
    end

    def unfollow(account)
      account_action(account, "unfollow").next{ |ret|
        if @@followings[uri.to_s]
          @@followings[uri.to_s].delete_if do |acc|
            acc.acct == account.acct
          end
          followings(cache: false)
        end
        ret
      }
    end

    def mute(account)
      account_action(account, "mute").next{ update_mutes! }
    end

    def unmute(account)
      account_action(account, "unmute").next{ update_mutes! }
    end

    def block(account)
      account_action(account, "block").next{
        if @@followings[uri.to_s]
          @@followings[uri.to_s].delete_if do |acc|
            acc.acct == account.acct
          end
        end
        blocks
      }
    end

    def unblock(account)
      account_action(account, "unblock").next{ blocks }
    end

    def pin(status)
      Plugin::Mastodon::API.get_local_status_id(self, status).next{ |status_id|
        Plugin::Mastodon::API.call(:post, domain, "/api/v1/statuses/#{status_id}/pin", access_token)
      }.next{
        status.pinned = true
      }
    end

    def unpin(status)
      Plugin::Mastodon::API.get_local_status_id(self, status).next{ |status_id|
        Plugin::Mastodon::API.call(:post, domain, "/api/v1/statuses/#{status_id}/unpin", access_token)
      }.next{
        status.pinned = false
      }
    end

    def report_for_spam(statuses, comment)
      Deferred.when(
        Plugin::Mastodon::API.get_local_account_id(self, statuses.first.account),
        Deferred.when(statuses.map { |status| Plugin::Mastodon::API.get_local_status_id(self, status) })
      ).next{ |account_id, spam_ids|
        Plugin::Mastodon::API.call(:post, domain, "/api/v1/reports", access_token,
                     account_id: account_id,
                     status_ids: spam_ids,
                     comment: comment)
      }
    end

    def update_account
      Plugin::Mastodon::API.call(:get, domain, '/api/v1/accounts/verify_credentials', access_token).next{ |resp|
        resp[:acct] = resp[:acct] + '@' + domain
        self.account = Plugin::Mastodon::Account.new(resp.value)
        Plugin.call(:world_modify, self)
      }
    end

    def update_profile(**opts)
      params = {}

      # 以下の2つはupdate_profile*系spellのAPIとしてのパラメータ名とMastodon APIのパラメータ名に違いがある

      # 表示名
      params[:display_name] = opts[:name] if opts[:name]
      # bio
      params[:note] = opts[:biography] if opts[:biography]

      # フォロー承認制
      params[:locked] = opts[:locked] if opts[:locked]
      # botアカウントであることの表明
      params[:bot] = opts[:bot] if opts[:bot]
      if [:privacy, :sensitive, :language].any?{|key| opts[:source] && opts[:source][key] }
        params[:source] = Hash.new
        # デフォルト公開範囲
        params[:source][:privacy] = opts[:source_privacy] if opts[:source_privacy]
        # デフォルトでNSFW
        params[:source][:sensitive] = opts[:source_sensitive] if opts[:source_sensitive]
        # 投稿する言語設定（ISO639-1形式（ex: "ja"） or nil（自動検出））
        params[:source][:language] = opts[:source_language] if opts[:source_language]
      end
      # プロフィール補足情報
      if (1..4).any?{|i| opts[:"field_name#{i}"] && opts[:"field_value#{i}"] }
        params[:fields_attributes] = Array.new
        (1..4).each do |i|
          name = opts[:"field_name#{i}"]
          next unless name
          value = opts[:"field_value#{i}"]
          next unless value
          params[:fields_attributes] << { name: name, value: value }
        end
      end
      ds = []
      if opts[:icon]
        if opts[:icon].is_a?(Plugin::Photo::Photo)
          ds << opts[:icon].download.next{|photo| [:avatar, photo] }
        else
          params[:avatar] = opts[:icon]
        end
      end
      if opts[:header]
        if opts[:header].is_a?(Plugin::Photo::Photo)
          ds << opts[:header].download.next{|photo| [:header, photo] }
        else
          params[:header] = opts[:header]
        end
      end
      if ds.empty?
        ds << Delayer::Deferred.new.next{ [:none, nil] }
      end
      Delayer::Deferred.when(ds).next{|vs|
        vs.each do |key, val|
          params[key] = val
        end
        new_account = +Plugin::Mastodon::API.call(:patch, domain, '/api/v1/accounts/update_credentials', access_token, **params)
        self.account = Plugin::Mastodon::Account.new(new_account.value)
        Plugin.call(:world_modify, self)
      }
    end
  end
end
