# -*- coding: utf-8 -*-

Plugin.create(:settings) do
  command(:open_setting,
          name: _('設定'),
          condition: :itself.to_proc,
          visible: true,
          icon: Skin[:settings],
          role: :window) do |opt|
    Plugin.call(:open_setting)
  end
end
