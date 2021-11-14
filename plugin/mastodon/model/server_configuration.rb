# frozen_string_literal: true

module Plugin::Mastodon
  class ServerConfigurationStatus < Diva::Model
    field.int :max_characters, required: false
    field.int :max_media_attachments, required: false
    field.int :characters_reserved_per_url, required: false
  end

  class ServerConfiguration < Diva::Model
    field.has :statuses, ServerConfigurationStatus, required: false
    # field.has :media_attachments, ServerConfigurationMediaAttachment, required: false
    # field.has :polls, ServerConfigurationPoll, required: false
  end
end
