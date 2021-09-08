# frozen_string_literal: true

module Plugin::MastodonAccountViewer
  class RelationalMenu < Gtk::Menu
    def initialize(relation)
      super()

      @relation = relation

      ssc(:selection_done) do
        destroy
        false
      end

      ssc(:cancel) do
        destroy
        false
      end

      append(gen_menu_mute)
      append(gen_menu_block)
    end

    private

    def gen_menu_mute
      item = Gtk::MenuItem.new(@relation.mute? ? _('ミュート解除する') : _('ミュートする'))
      item.ssc(:activate) do
        @relation.request_update_mute_status(!@relation.mute?)
        true
      end
      item
    end

    def gen_menu_block
      item = Gtk::MenuItem.new(@relation.blocked? ? _('ブロック解除する') : _('ブロックする'))
      item.ssc(:activate) do
        @relation.request_update_block_status(!@relation.blocked?)
      end
      item
    end

    def _(*rest)
      Plugin[:mastodon_account_viewer]._(*rest)
    end
  end
end
