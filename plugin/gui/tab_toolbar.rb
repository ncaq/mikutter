# -*- coding: utf-8 -*-

require_relative 'pane'
require_relative 'cuscadable'
require_relative 'hierarchy_child'
require_relative 'tab'
require_relative 'widget'

# タブにコマンドを表示するウィジェット
class Plugin::GUI::TabToolbar

  include Plugin::GUI::Cuscadable
  include Plugin::GUI::HierarchyChild
  include Plugin::GUI::Widget

  role :tab_toolbar

  set_parent_event :gui_tab_toolbar_join_tab

  def initialize(*args)
    super
    Plugin.call(:tab_toolbar_created, self)
  end

  def rewind
    Plugin.call(:tab_toolbar_rewind, self)
  end

end
