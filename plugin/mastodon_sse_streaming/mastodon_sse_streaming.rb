# frozen_string_literal: true

require_relative 'connection'
require_relative 'handler/favorite'
require_relative 'handler/follow'
require_relative 'handler/poll'
require_relative 'handler/reblog'
require_relative 'handler/update'

Plugin.create(:mastodon_sse_streaming) do
  # TODO: UserConfig[:mastodon_enable_streaming] の設定をできるようにする

  subscribe(:mastodon_worlds__add).each do |new_world|
    [new_world.sse.user,
     new_world.sse.direct,
     new_world.sse.public,
     new_world.sse.public_local,
     new_world.sse.public(only_media: true),
     new_world.sse.public_local(only_media: true)].each { |stream| generate_stream(stream, tag: tag_of(new_world)) }
    new_world.get_lists.next { |lists|
      lists.each do |l|
        generate_stream(new_world.sse.list(list_id: l[:id].to_i, title: l[:title]), tag: tag_of(new_world))
      end
    }.terminate(_('Mastodon: リスト取得時にエラーが発生しました'))
    generate_notification_stream(new_world.sse.user, tag: tag_of(new_world))
  end

  subscribe(:mastodon_worlds__delete).each do |lost_world|
    detach(tag_of(lost_world))
  end

  subscribe(:mastodon_servers__add).each do |server|
    generate_stream(server.sse.public,                         tag: tag_of(server))
    generate_stream(server.sse.public_local,                   tag: tag_of(server))
    generate_stream(server.sse.public(only_media: true),       tag: tag_of(server))
    generate_stream(server.sse.public_local(only_media: true), tag: tag_of(server))
  end

  subscribe(:mastodon_servers__delete).each do |lost_server|
    detach(tag_of(lost_server))
  end

  def generate_stream(connection_type, tag:)
    generate(:extract_receive_message, connection_type.datasource_slug, tags: [tag]) do |stream_input|
      connection_pool(connection_type).add_handler(
        Plugin::MastodonSseStreaming::Handler::Update.new(
          connection_type,
          &stream_input.method(:<<)
        )
      )
    end
  end

  def generate_notification_stream(connection_type, tag:)
    connection_pool(connection_type).add_handler(
      Plugin::MastodonSseStreaming::Handler::Reblog.new(
        connection_type,
        &Plugin.method(:call).curry(3).(:share)
      )
    ).add_handler(
      Plugin::MastodonSseStreaming::Handler::Favorite.new(
        connection_type,
        &Plugin.method(:call).curry(4).(:favorite, connection_type.world)
      )
    ).add_handler(
      Plugin::MastodonSseStreaming::Handler::Follow.new(
        connection_type
      ) do |user|
        Plugin.call(:followers_created, connection_type.world, [user])
      end
    ).add_handler(
      Plugin::MastodonSseStreaming::Handler::Poll.new(
        connection_type
      ) do |message|
        activity(:poll, _('投票が終了しました'), description: message.uri.to_s)
      end
    )
  end

  def connection_pool(connection_type)
    @connection_pool ||= {}
    @connection_pool[connection_type.uri] ||= Plugin::MastodonSseStreaming::Connection.new(
      connection_type
    ).tap(&:run)
  end

  @tags = {}                    # world_hash => handler_tag
  def tag_of(world_or_server)
    @tags[world_or_server.hash] ||= handler_tag
  end
end
