# -*- coding: utf-8 -*-

require 'mui/cairo_sub_parts_voter'

require 'gtk3'
require 'cairo'

class Gdk::SubPartsFavorite < Gdk::SubPartsVoter
  extend Memoist

  register

  def get_vote_count
    if helper.message.respond_to?(:favorite_count)
      helper.message.favorite_count || super || 0
    else
      [helper.message[:favorite_count] || 0, super].max
    end
  end

  def get_default_votes
    helper.message.favorited_by.to_a
  end

  memoize def title_icon_model
    Skin.photo(:unfav)
  end

  def name
    :favorited end
end
