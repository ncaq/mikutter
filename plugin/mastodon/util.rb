module Plugin::Mastodon
  class Util
    class << self
      def deep_dup(obj)
        Marshal.load(Marshal.dump(obj))
      end

      def ppf(obj)
        pp obj
        $stdout.flush
      end

      def visibility2select(s)
        case s
        when "public"
            :"1public"
        when "unlisted"
            :"2unlisted"
        when "private"
            :"3private"
        when "direct"
            :"4direct"
        else
          nil
        end
      end

      def select2visibility(s)
        case s
        when :"1public"
          "public"
        when :"2unlisted"
          "unlisted"
        when :"3private"
          "private"
        when :"4direct"
          "direct"
        else
          nil
        end
      end
    end
  end
end
