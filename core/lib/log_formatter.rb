# frozen_string_literal: true

require 'logger'

module LogFormatter
  FOLLOW_DIR = File.expand_path(File.join(__dir__, '..', '..'))

  class Standard < Logger::Formatter
    def call(severity, time, progname, message)
      super.gsub(FOLLOW_DIR, '{MIKUTTER_DIR}')
    end
  end
end
