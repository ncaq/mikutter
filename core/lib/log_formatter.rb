# frozen_string_literal: true

require 'logger'

module LogFormatter
  FOLLOW_DIR = File.expand_path(File.join(__dir__, '..', '..'))

  class Standard < Logger::Formatter
    def call(severity, time, progname, message)
      super.gsub(FOLLOW_DIR, '{MIKUTTER_DIR}')
    end
  end

  class Colorful < Logger::Formatter
    # based on Logger::Formatter::Format
    FORMAT = "\e[0m%{severity_decorate}%{short_severity}\e[0m, [%{datetime}\e[2m#%{pid}\e[0m] %{severity_decorate}%{severity}\e[0m -- \e[2m%{progname}:\e[0m %{message}\n"

    def call(severity, time, progname, message)
      # NOTE: stderrを出力先にしていることが前提
      if $stderr.tty?
        msg = FORMAT % {
          severity: severity.rjust(5),
          short_severity: severity[0..0],
          severity_decorate: severity_decorate(severity),
          datetime: format_datetime(time),
          pid: Process.pid,
          progname: progname,
          message: msg2str(message)
        }
        msg.gsub(FOLLOW_DIR, '{MIKUTTER_DIR}')
      else
        super.gsub(FOLLOW_DIR, '{MIKUTTER_DIR}')
      end
    end

    private

    # severityに対応する装飾用のエスケープシーケンスを返す
    def severity_decorate(severity)
      case severity
      when 'INFO'
        "\e[36m"
      when 'WARN'
        "\e[33m"
      when 'ERROR'
        "\e[1;31m"
      else
        ''
      end
    end
  end
end
