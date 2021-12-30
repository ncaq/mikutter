# frozen_string_literal: true

module Plugin::Mastodon
  class RestAuthorizedType < Diva::Model
    field.has :world, Plugin::Mastodon::World, required: true

    attr_reader :datasource_slug
    attr_reader :title
    attr_reader :perma_link
    attr_reader :response_entities

    def server
      world.server
    end

    def token
      world.access_token
    end

    def user
      @datasource_slug = "mastodon-#{world.account.acct}-home".to_sym
      @title = Plugin[:mastodon]._("Mastodonホームタイムライン(Mastodon)/%{acct}") % {acct: world.account.acct}
      set_endpoint_timelines('home')
    end

    def mention
      @datasource_slug = "mastodon-#{world.account.acct}-mentions".to_sym
      @title = Plugin[:mastodon]._('Mastodon/%{domain}/%{acct}/Mentions') % {domain: world.server.domain, acct: world.account.acct}
      set_endpoint_notifications(exclude_types: %w[follow follow_request favourite reblog poll])
    end

    def direct
      @datasource_slug = "mastodon-#{world.account.acct}-direct".to_sym
      @title = Plugin[:mastodon]._("Mastodon DM(Mastodon)/%{acct}") % {acct: world.account.acct}
      set_endpoint_timelines('direct')
    end

    def list(list_id:, title:)
      # params[:list] = list_id
      @datasource_slug = "mastodon-#{world.account.acct}-list-#{list_id}".to_sym
      @title = Plugin[:mastodon]._("Mastodonリスト(Mastodon)/%{acct}/%{title}") % {acct: world.account.acct, title: title}
      set_endpoint_timelines("list/#{list_id}")
    end

    def public(only_media: false)
      params[:only_media] = only_media
      @datasource_slug =
        if only_media
          "mastodon-#{world.account.acct}-federated-media".to_sym
        else
          "mastodon-#{world.account.acct}-federated".to_sym
        end
      set_endpoint_timelines('public')
    end

    def public_local(only_media: false)
      params[:only_media] = only_media
      params[:local] = 1
      @datasource_slug =
        if only_media
          "mastodon-#{world.account.acct}-local-media".to_sym
        else
          "mastodon-#{world.account.acct}-local".to_sym
        end
      set_endpoint_timelines('public')
    end

    def set_endpoint_timelines(endpoint)
      @perma_link = Diva::URI.new('https://%{domain}/api/v1/timelines/%{endpoint}' % {
                             domain:   server.domain,
                             endpoint: endpoint,
                                  })
      @response_entities = :status
      self
    end

    def set_endpoint_notifications(exclude_types: [].freeze)
      @perma_link = Diva::URI.new('https://%{domain}/api/v1/notifications' % {
                                    domain: server.domain
                                  })
      params[:exclude_types] = exclude_types.freeze
      @response_entities = :notification
      self
    end

    def params
      @params ||= {}
    end

    def inspect
      "#<#{self.class}: #{@datasource_slug} #{@perma_link}>"
    end
  end
end
