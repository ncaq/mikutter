# -*- coding: utf-8 -*-

module Plugin::Intent
  class IntentToken < Diva::Model
    field.uri    :uri, required: true
    field.has    :model, Diva::Model
    field.has    :intent, Plugin::Intent::Intent, required: true
    field.has    :parent, Plugin::Intent::IntentToken

    # 引数の情報からIntentTokenを作成し、それを開く
    def self.open(*args)
      self.new(*args).open
    end

    def initialize(*rest)
      super
      self[:source] = self[:model]
    end

    # 設定された情報を使ってURI又はModelを開く
    def open
      if model?
        Plugin.call(:open, self)
      else
        Deferred.new{
          Diva.Model(intent.model_slug).find_by_uri(uri)
        }.next{|m|
          Delayer::Deferred.fail("#{intent.model_slug}(#{uri}) does not exists.") unless m
          self.model = m
          Plugin.call(:open, self)
        }.trap{|err|
          error err
          forward
        }
      end
      self
    end

    def forward
      Plugin.call(:intent_forward, self)
    end

    # _self_ から親のIntentTokenを再帰的に遡って、そのIntentTokenを引数に繰り返すEnumeratorを返す。
    # ==== Return
    # [Enumerator] IntentTokenを列挙する
    def ancestors
      Enumerator.new do |yielder|
        cur = self
        loop do
          break unless cur
          yielder << cur
          cur = cur.parent
        end
      end
    end

    # ancestorsと同じようなもの。ただし、IntentToken#intentに関して繰り返す。
    # ==== Return
    # [Enumerator] Intentを列挙する
    def intent_ancestors
      ancestors.lazy.map(&:intent)
    end
  end
end
