# frozen_string_literal: true

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
          instance.push! model
        end
      end

      def remove_rows(model)
        @@instances.each do |instance|
          instance.remove! model
        end
      end
    end

    # used for deprecation year and month
    YM = [2019, 10].freeze

    extend Gem::Deprecate

    attr_reader :postbox
    attr_reader :listbox
    attr_accessor :order

    def initialize(imaginary=nil)
      super()

      @@instances.push self

      self.name = 'timeline'
      self.orientation = :vertical

      @imaginary = imaginary
      @hash = {} # Diva::URI => Row
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

      add @postbox
      add(Gtk::ScrolledWindow.new.tap do |sw|
        sw.set_policy :never, :automatic
        sw.expand = true
        sw.add @listbox
      end)
    end

    def include?(model)
      ! @hash[model.uri.hash].nil?
    end

    def destroyed?
      # TODO
      false
    end

    def active!
      # TODO
      raise NotImplementedError
    end
    alias active active!
    deprecate :active, :active!, *YM

    def push!(model)
      check_and_push! model
    end
    alias modified push!
    deprecate :modified, :push!, *YM
    alias favorite push!
    deprecate :favorite, :push!, *YM
    alias unfavorite push!
    deprecate :unfavorite, :push!, *YM

    def push_all!(models)
      models.each(&method(:check_and_push!))
    end
    alias block_add_all push_all!
    deprecate :block_add_all, :push_all!, *YM
    alias remove_if_exists_all push_all!
    deprecate :remove_if_exists_all, :push_all!, *YM
    alias add_retweets push_all!
    deprecate :add_retweets, :push_all!, *YM

    def remove!(model)
      row = @hash[model.uri.hash] or return
      @listbox.remove row
    end

    def clear!
      # TODO
      raise NotImplementedError
    end
    alias clear clear!
    deprecate :clear, :clear!, *YM

  private

    def check_and_push!(model)
      row = @hash[model.uri.hash]
      row and @listbox.remove row

      row = MiraclePainter.new model
      row.show_all
      @listbox.add row
      @hash[model.uri.hash] = row
    end
  end
end
