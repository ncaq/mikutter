# frozen_string_literal: true

# temporary monkey patch

module GObjectIntrospection::Loader::VirtualFunctionImplementable
  def implement_virtual_function(implementor_class, name)
    unless instance_variable_defined?(:@virtual_function_implementor)
      return false
    end
    @virtual_function_implementor.implement(implementor_class.gtype,
                                            name)
  end
end
