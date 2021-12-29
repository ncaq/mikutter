# -*- coding: utf-8 -*-

require_relative 'console_control'

Plugin.create :console do
  command(:console_open,
          name: _('コンソールを開く'),
          condition: lambda{ |opt| true },
          visible: true,
          icon: Skin[:console],
          role: :pane) do |opt|
    if Plugin::GUI::Tab.cuscaded.has_key?(:console)
      Plugin::GUI::Tab.instance(:console).active!
      next end
    widget_result = ::Gtk::TextView.new
    widget_input = ::Gtk::TextView.new

    widget_result.set_editable(false)

    widget_result.set_size_request(0, 50)
    widget_input.set_size_request(0, 50)

    widget_result.buffer.insert(widget_result.buffer.start_iter, _("mikutter console.\n下にRubyコードを入力して、Ctrl+Enterを押すと、ここに実行結果が表示されます") + "\n")

    gen_tags(widget_result.buffer)

    widget_input.ssc('key_press_event'){ |widget, event|
      if "Control + Return" == ::Gtk::keyname([event.keyval ,event.state])
        iter = widget_result.buffer.end_iter
        begin
          result = Kernel.instance_eval(widget.buffer.text)
          widget_result.buffer.insert(iter, ">>> ", { tags: %w[prompt] })
          widget_result.buffer.insert(iter, "#{widget.buffer.text}\n", { tags: %w[echo] })
          widget_result.buffer.insert(iter, "#{result.inspect}\n", { tags: %w[result] })
        rescue Exception => e
          widget_result.buffer.insert(iter, ">>> ", { tags: %w[prompt] })
          widget_result.buffer.insert(iter, "#{widget.buffer.text}\n", { tags: %w[echo] })
          widget_result.buffer.insert(iter, "#{e.class}: ", { tags: %w[errorclass] })
          widget_result.buffer.insert(iter, "#{e}\n", { tags: %w[error] })
          widget_result.buffer.insert(iter, e.backtrace.join("\n") + "\n", { tags: %w[backtrace] })
        end
        Delayer.new {
          if not widget_result.destroyed?
            widget_result.scroll_to_iter(iter, 0.0, false, 0, 1.0) end }
        true
      else
        false end }

    tab(:console, _("コンソール")) do
      set_icon Skin[:console]
      set_deletable true
      temporary_tab
      nativewidget Plugin::Console::ConsoleControl.new(:vertical).
                     pack1(::Gtk::ScrolledWindow.new.tap { |w| w.add(widget_result) }, resize: true, shrink: false).
                     pack2(::Gtk::ScrolledWindow.new.tap { |w| w.add(widget_input) }, resize: false, shrink: false)
      active!
    end
  end

  # タグを作る
  # ==== Args
  # [buffer] Gtk::TextBuffer
  def gen_tags(buffer)
    type_strict buffer => ::Gtk::TextBuffer
    buffer.create_tag("prompt",
                      foreground_rgba: Gdk::RGBA.parse('#006600'))
    buffer.create_tag("echo",
                      weight: Pango::Weight::BOLD)
    buffer.create_tag("result",
                      foreground_rgba: Gdk::RGBA.parse('#000066'))
    buffer.create_tag("errorclass",
                      foreground_rgba: Gdk::RGBA.parse('#660000'))
    buffer.create_tag("error",
                      weight: Pango::Weight::BOLD,
                      foreground_rgba: Gdk::RGBA.parse('#990000'))
    buffer.create_tag("backtrace",
                      foreground_rgba: Gdk::RGBA.parse('#330000'))
  end

end
