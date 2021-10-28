# -*- coding: utf-8 -*-

require 'mui/cairo_sub_parts_voter'

require 'gtk3'
require 'cairo'

class Gdk::SubPartsShare < Gdk::SubPartsVoter
  extend Memoist

  register

  def get_vote_count
    if helper.message.respond_to?(:retweet_count)
      helper.message.retweet_count || super || 0
    else
      [helper.message[:retweet_count] || 0, super].max
    end
  end

  def get_default_votes
    helper.message.retweeted_by.to_a
  end

  memoize def title_icon_model
    Skin.photo(:retweet)
  end

  def name
    :shared end
end
