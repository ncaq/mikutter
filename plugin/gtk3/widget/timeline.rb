# frozen_string_literal: true

require 'pqueue'

require 'mui/gtk_postbox'

module Plugin::Gtk3
=begin rdoc
  投稿ボックスとスクロール可能のリストビューを備えたウィジェット
=end
  class Timeline < Gtk::Grid
    class << self
      @@instances = []

      def update_rows(model)
        @@instances.each do |instance|
          instance.bulk_add [model]
        end
      end

      def remove_rows(model)
        @@instances.each do |instance|
          instance.bulk_remove [model]
        end
      end
    end

    type_register

    # used for deprecation year and month
    YM = [2019, 10].freeze

    extend Gem::Deprecate

    attr_reader :postbox
    attr_reader :order

    def initialize(imaginary=nil)
      super()

      @@instances.push self

      self.name = 'timeline'
      self.orientation = :vertical

      @imaginary = imaginary
      @hash = {} # Diva::URI => Row
      @pq = PQueue.new { |a, b| a.modified < b.modified }
      @order = ->(m) { m.modified.to_i }
      @postbox = Gtk::Grid.new.tap do |grid|
        grid.orientation = :vertical
      end
      @listbox = Gtk::ListBox.new.tap do |listbox|
        listbox.selection_mode = :single
        listbox.set_sort_func do |row1, row2|
          (@order.call row2.model) <=> (@order.call row1.model)
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

    def include?(model)
      ! @hash[model.uri.hash].nil?
    end

    def active
      @imaginary.active!
    end

    def keypress(keyname)
      Plugin::GUI.keypress keyname, @imaginary
    end

    def bulk_add(models)
      models.each(&method(:check_and_add))
    end

    def bulk_remove(models)

      models.each(&method(:check_and_remove))
    end

    def clear
      raise NotImplementedError
    end

    def size
      @listbox.children.size
    end

    def select_row_at_index(index)
      selected_rows.each do |row|
        @listbox.unselect_row row
      end
      @listbox.select_row @listbox.get_row_at_index index
    end

    def jump_to(to)
      case to
      when :top
        @listbox.adjustment.value = @listbox.adjustment.lower
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
      menu.ssc(:deactivate, &:destroy)
      menu.attach_to_widget self

      ev, menus = Plugin::GUI::Command.get_menu_items @imaginary
      notice menus
      Gtk::ContextMenu.new(*menus).build!(self, ev, menu = menu)

      menu.show_all
      menu.popup_at_pointer event
    end

  private

    def check_and_add(model)
      row = @hash[model.uri.to_s]
      row and @listbox.remove row

      row = MiraclePainter.new model
      row.show_all
      @listbox.add row
      @hash[model.uri.to_s] = row
      @pq.push model

      resize if size > 1000
    end

    def check_and_remove(model)
      row = @hash[model.uri.to_s] or return
      @hash.delete model.uri.to_s
      @listbox.remove row
    end

    def resize
      model = @pq.pop or return
      row = @hash[model.uri.to_s] or return
      @listbox.remove row
      @hash.delete row
    end
  end
end
