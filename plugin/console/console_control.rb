# -*- coding: utf-8 -*-

module Plugin::Console
  class ConsoleControl < Gtk::Paned
    def active
      get_ancestor(Gtk::Window).set_focus(child2) if(get_ancestor(Gtk::Window))
    end
  end
end




