# -*- coding: utf-8 -*-

require 'mui/cairo_sub_parts_voter'

require 'gtk3'
require 'cairo'

class Gdk::SubPartsShare < Gdk::SubPartsVoter
  extend Memoist

  register

  def get_vote_count
    [helper.message[:retweet_count] || 0, super].max
  end

  def get_default_votes
    helper.message.retweeted_by || []
  end

  memoize def title_icon_model
    Skin[:retweet]
  end

  def name
    :shared end
end
