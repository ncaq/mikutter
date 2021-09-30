# -*- coding: utf-8 -*-

require 'userconfig'

require 'gtk3'
require 'cairo'

module Gdk::SubPartsHelper
  extend Gem::Deprecate

  # 今サポートされている全てのSubPartsを配列で返す
  # ==== Return
  # Subpartsクラスの配列
  def self.subparts_classes
    @subparts_classes ||= [] end

  def subparts
    @subparts ||= Gdk::SubPartsHelper.subparts_classes.map{ |klass| klass.new(self) } end

  def render_parts(context)
    context.save{
      mainpart_height
      context.translate(0, mainpart_height)
      subparts.each{ |part|
        context.save{
          part.render(context) }
        context.translate(0, part.height) } }
    self end

  def subparts_height
    subparts.sum(&:height)
  end
end

class Gdk::SubParts
  extend Gem::Deprecate

  attr_reader :helper

  class << self
    extend Gem::Deprecate

    def register
      index = where_should_insert_it(self.to_s, Gdk::SubPartsHelper.subparts_classes.map(&:to_s), UserConfig[:subparts_order] || [])
      Gdk::SubPartsHelper.subparts_classes.insert(index, self)
    end

    alias :regist :register
    deprecate :regist, "register", 2016, 12
  end

  def initialize(helper)
    @helper = helper
  end

  def render(context)
  end

  def width
    helper.allocated_width end

  def height
    0 end
end
