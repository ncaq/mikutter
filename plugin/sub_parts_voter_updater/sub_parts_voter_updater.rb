# frozen_string_literal: true

Plugin.create(:sub_parts_voter_updater) do
  on_favorite do |_world, user, message|
    Plugin::Gtk3::Timeline.miracle_painters_of(message).each do |mp|
      if !mp.destroyed?
        mp.subparts.find{ |sp| sp.class == Gdk::SubPartsFavorite }.add(user)
      end
    end
  end

  on_before_favorite do |_world, user, message|
    Plugin::Gtk3::Timeline.miracle_painters_of(message).each do |mp|
      if !mp.destroyed?
        mp.subparts.find{ |sp| sp.class == Gdk::SubPartsFavorite }.add(user)
      end
    end
  end

  on_fail_favorite do |_world, user, message|
    Plugin::Gtk3::Timeline.miracle_painters_of(message).each do |mp|
      if !mp.destroyed?
        mp.subparts.find{ |sp| sp.class == Gdk::SubPartsFavorite }.delete(user)
      end
    end
  end

  share = ->(user, message) {
    Plugin::Gtk3::Timeline.miracle_painters_of(message).each do |mp|
      if !mp.destroyed?
        mp.subparts.find { |sp| sp.class == Gdk::SubPartsShare }.add(user)
      end
    end
  }

  on_share(&share)
  on_before_share(&share)

  destroy_share = ->(user, message) do
    Plugin::Gtk3::Timeline.miracle_painters_of(message).each do |mp|
      if !mp.destroyed?
        mp.subparts.find { |sp| sp.class == Gdk::SubPartsShare }.delete(user)
      end
    end
  end

  on_fail_share(&destroy_share)
  on_destroy_share(&destroy_share)
end
