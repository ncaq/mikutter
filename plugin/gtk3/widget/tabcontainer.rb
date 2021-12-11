# -*- coding: utf-8 -*-

class Plugin::Gtk3::TabContainer < Gtk::Box
  attr_reader :i_tab

  def initialize(tab)
    type_strict tab => Plugin::GUI::TabLike
    @i_tab = tab
    super(:vertical, 0)
  end

  def to_sym
    i_tab.slug end
  alias slug to_sym

  def inspect
    "#<TabContainer(i_tab=#{i_tab})>"
  end
  alias to_s inspect
end
