# frozen_string_literal: true

# ruby-gnome 3.5.0 早くでないかなー!!
if GLib::BINDING_VERSION < [3, 5, 0]
  # 直接のスーパークラスより上の祖先が持つvfuncを実装できないバグの修正
  # https://github.com/ruby-gnome/ruby-gnome/pull/1433
  module GObjectIntrospection::Loader::VirtualFunctionImplementable
    def implement_virtual_function(implementor_class, name)
      unless instance_variable_defined?(:@virtual_function_implementor)
        return false
      end
      @virtual_function_implementor.implement(implementor_class.gtype,
                                              name)
    end
  end

  # 3.5.0 で定数名が変わったやつ
  module PangoCairo
    Pango.constants.filter { |name| name.to_s.start_with?('Cairo') }.each do |name|
      const_set(name.to_s.delete_prefix('Cairo'), Pango.const_get(name))
    end
  end
end
