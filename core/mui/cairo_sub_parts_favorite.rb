# -*- coding: utf-8 -*-

require 'mui/cairo_sub_parts_voter'

require 'gtk3'
require 'cairo'

class Gdk::SubPartsFavorite < Gdk::SubPartsVoter
  extend Memoist

  register

  def get_vote_count
    [helper.message[:favorite_count] || 0, super].max
  end

  def get_default_votes
    helper.message.favorited_by
  end

  memoize def title_icon_model
    Skin.photo('unfav.png')
  end

  def name
    :favorited end
end
