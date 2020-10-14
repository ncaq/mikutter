# -*- coding: utf-8 -*-
# frozen_string_literal: true

require_relative 'relational_container'

Plugin.create(:mastodon_account_viewer) do
  defmodelviewer(Plugin::Mastodon::Account) do |user|
    since_day = (Time.now - user.created_at).to_i / (60 * 60 * 24)
    param_mastodon_start_date = {
      year: user.created_at.strftime('%Y'),
      month: user.created_at.strftime('%m'),
      day: user.created_at.strftime('%d'),
      hour: user.created_at.strftime('%H'),
      minute: user.created_at.strftime('%M'),
      second: user.created_at.strftime('%S'),
      since_day: since_day
    }
    param_toot_count = {
      count: user.statuses_count,
      toots_per_day: since_day == 0 ? user.statuses_count : '%{avg}.2f' % { avg: Rational(user.statuses_count, since_day).to_f }
    }
    [
      [_('名前'), user.display_name],
      [_('acct'), user.acct],
      [_('フォロー'), user.following_count],
      [_('フォロワー'), user.followers_count],
      [_('Mastodon開始'), _('%{year}/%{month}/%{day} %{hour}:%{minute}:%{second} (%{since_day}日)') % param_mastodon_start_date],
      [_('Toot'), _('%{count} (%{toots_per_day}toots/day)') % param_toot_count]
    ].freeze
  end

  deffragment(Plugin::Mastodon::Account, :bio, _('ユーザについて')) do |user|
    set_icon user.icon
    score = score_of(user.profile)
    bio = ::Gtk::IntelligentTextview.new(score)
    container = Gtk::VBox.new.
                  closeup(user_field_table(
                            user.fields&.map do |f|
                              f.emojis ||= user.emojis
                              [f.name, f]
                            end
                          )).
                  closeup(bio).
                  closeup(relation_bar(user))
    scrolledwindow = ::Gtk::ScrolledWindow.new
    scrolledwindow.set_policy(::Gtk::POLICY_AUTOMATIC, ::Gtk::POLICY_AUTOMATIC)
    scrolledwindow.add_with_viewport(container)
    scrolledwindow.style = container.style
    wrapper = Gtk::EventBox.new
    wrapper.no_show_all = true
    wrapper.show
    nativewidget wrapper.add(scrolledwindow)
    wrapper.ssc(:expose_event) do
      wrapper.no_show_all = false
      wrapper.show_all
      false
    end
  end

  def user_field_table(header_columns)
    ::Gtk::Table.new(2, header_columns.size).tap { |table|
      header_columns.each_with_index do |(key, value), index|
        table.
          attach(::Gtk::Label.new(key.to_s).right, 0, 1, index, index + 1).
          attach(cell_widget(value), 1, 2, index, index + 1)
      end
    }.set_row_spacing(0, 4).
      set_row_spacing(1, 4).
      set_column_spacing(0, 16)
  end

  def cell_widget(model_or_str)
    case model_or_str
    when Diva::Model
      ::Gtk::IntelligentTextview.new(
        Plugin[:modelviewer].score_of(model_or_str)
      )
    else
      ::Gtk::IntelligentTextview.new(model_or_str.to_s)
    end
  end

  # フォロー関係の表示・操作用ウィジェット
  def relation_bar(user)
    container = ::Gtk::VBox.new(false, 4)
    Plugin.collect(:mastodon_worlds).each do |me|
      container.closeup(Plugin::MastodonAccountViewer::RelationalContainer.new(me, user, self))
    end
    container
  end

  def request_unmute(world, user)
    unmute_user(world, user)
  end

  def request_mute(world, user)
    dialog(_('ミュートする')) {
      label _('以下のユーザーをミュートしますか？')
      link user
    }.next do
      mute_user(world, user)
    end
  end

  def request_unblock(world, user)
    unblock_user(world, user)
  end

  def request_block(world, user)
    dialog(_('ブロックする')) {
      label _('以下のユーザーをブロックしますか？')
      link user
    }.next do
      block_user(world, user)
    end
  end

  def request_unfollow(world, user)
    unfollow_user(world, user)
  end

  def request_follow(world, user)
    follow_user(world, user)
  end

  deffragment(Plugin::Mastodon::Account, :user_timeline, _('ユーザタイムライン')) do |user|
    set_icon Skin[:timeline]
    tl = timeline(nil) do
      order do |message|
        retweet = message.retweeted_statuses.find { |r| user.id == r.user.id }
        (retweet || message).created.to_i
      end
    end
    world, = Plugin.filtering(:mastodon_current, nil)
    Plugin::Mastodon::API.get_local_account_id(world, user).next { |account_id|
      Plugin::Mastodon::API.call(:get, world.domain, "/api/v1/accounts/#{account_id}/statuses", world.access_token).next do |res|
        tl << Plugin::Mastodon::Status.bulk_build(world.server, res.value)
      end
    }.terminate
    acct, domain = user.acct.split('@', 2)
    if domain != world.domain
      Plugin::Mastodon::API.call(
        :get,
        domain,
        "/users/#{acct}/outbox?page=true",
        nil,
        {},
        { 'Accept' => 'application/activity+json' }
      ).next { |res|
        res[:orderedItems].map { |record|
          case record[:type]
          when 'Create'
            # トゥート
            record.dig(:object, :url)
          when 'Announce'
            # ブースト
            Plugin::Mastodon::Status::TOOT_ACTIVITY_URI_RE.match(record[:atomUri]) do |m|
              "https://#{m[:domain]}/@#{m[:acct]}/#{m[:status_id]}"
            end
          end
        }.compact.each do |url|
          status = Plugin::Mastodon::Status.findbyuri(url) || +Plugin::Mastodon::Status.fetch(url)
          tl << status if status
        end
      }.terminate
    end
  end
end
