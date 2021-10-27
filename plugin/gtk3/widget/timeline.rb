# frozen_string_literal: true

require 'mui/gtk_postbox'

module Plugin::Gtk3
  # 投稿ボックスとスクロール可能のリストビューを備えたウィジェット
  class Timeline < Gtk::Grid
    class << self
      attr_accessor :current

      def update_rows(model)
        @instances.each do |instance|
          instance.bulk_add([model]) if instance.include?(model)
        end
      end

      def remove_rows(model)
        @instances.each do |instance|
          instance.bulk_remove [model]
        end
      end

      def miracle_painters_of(message)
        Enumerator.new do |yielder|
          @instances.each do |instance|
            detect = instance.find_miracle_painter_by_message(message)
            yielder << detect if detect
          end
        end
      end

      def new(*)
        instance = super
        (@instances ||= []).push(instance)
        @current ||= instance
        instance
      end
    end

    type_register

    attr_reader :postbox, :order, :imaginary

    def initialize(imaginary=nil)
      super()

      self.name = 'timeline'
      self.orientation = :vertical

      @uri_mp_dict = {} # { String (model uri) => MiraclePainter }
      @imaginary = imaginary
      @order = ->(m) { m.modified.to_i }
      @postbox = Gtk::Grid.new.tap do |grid|
        grid.orientation = :vertical
      end
      @listbox = Gtk::ListBox.new.tap do |listbox|
        listbox.selection_mode = :multiple
        listbox.activate_on_single_click = false
        listbox.set_sort_func do |a, b|
          @order.(b.model) <=> @order.(a.model)
        end
      end
      @listbox.ssc :destroy do
        @imaginary.destroy
      end

      add @postbox
      add(Gtk::ScrolledWindow.new.tap do |sw|
            sw.set_policy :never, :automatic
            sw.expand = true
            sw.add @listbox
          end)
    end

    def order=(order)
      @order = order
      @listbox.invalidate_sort
    end

    def include?(message)
      @uri_mp_dict.key?(message.uri.to_s)
    end

    def active
      @imaginary.active!(true, true)

      if self.class.current && self.class.current != self && !self.class.current.destroyed?
        self.class.current.unselect_all
      end
      self.class.current = self
    end

    def keypress(keyname)
      Plugin::GUI.keypress keyname, @imaginary
    end

    def bulk_add(models)
      update_ordinal = false
      models.each do |m|
        message = m.retweet_source || m
        mp = find_miracle_painter_by_message(message)
        if mp
          update_ordinal |= @order.(mp.model) != @order.(message)
          mp.message = message
        else
          row = MiraclePainter.new(message)
          row.show_all
          @listbox.add(row)
          @uri_mp_dict[message.uri.to_s] = row
        end
      end
      @listbox.invalidate_sort if update_ordinal
      overflow = @listbox.children[1000..]
      bulk_remove(overflow.map(&:message)) if overflow
    end

    def bulk_remove(messages)
      messages.map { |message|
        @uri_mp_dict.delete(message.uri.to_s)
      }.to_a.compact.each(&@listbox.method(:remove))
    end

    def clear
      raise NotImplementedError
    end

    def size
      @uri_mp_dict.size
    end

    def select_row(row)
      @listbox.select_row(row) unless selected_rows.include?(row)
    end

    def select_row_at_index(index)
      unselect_all
      @listbox.select_row @listbox.get_row_at_index index
    end

    def unselect_all
      selected_rows.each do |row|
        @listbox.unselect_row row
      end
    end

    def jump_to(to)
      case to
      when :top
        @listbox.adjustment.value = @listbox.adjustment.lower
        select_row_at_index(0)
      when :up
        @listbox.adjustment.value -= @listbox.adjustment.page_increment
      when :down
        @listbox.adjustment.value += @listbox.adjustment.page_increment
      end
    end

    def selected_rows
      @listbox.selected_rows
    end

    def popup_menu(event)
      menu = Gtk::Menu.new
      menu.attach_to_widget self

      ev, menus = Plugin::GUI::Command.get_menu_items @imaginary
      Gtk::ContextMenu.new(*menus).build!(self, ev, menu = menu)

      menu.show_all
      menu.popup_at_pointer event

      # TODO: gtk3 参照を保持しておかないとGCされてしまう
      @menu = menu
    end

    def add_postbox(i_postbox)
      # ずっと表示される（投稿しても消えない）PostBoxの処理
      # 既にprocっぽいものが入っているときはそのままにしておく
      options = i_postbox.options.dup
      if options[:delegate_other] && !options[:delegate_other].respond_to?(:to_proc)
        i_timeline = i_postbox.ancestor_of(Plugin::GUI::Timeline)
        options[:delegate_other] = postbox_delegation_generator(i_timeline)
        options[:postboxstorage] = postbox
      end
      create_postbox(options)
    end

    def find_miracle_painter_by_message(message)
      @uri_mp_dict[message.uri.to_s]
    end

    private

    def create_postbox(options, &block)
      options = options.dup
      options[:before_post_hook] = ->(_this) {
        get_ancestor(Gtk::Window).set_focus(self) unless destroyed?
      }
      pb = Gtk::PostBox.new(**options).show_all
      postbox << pb
      pb.on_delete(&block) if block
      get_ancestor(Gtk::Window).set_focus(pb.post)
      pb
    end
  end
end
