# -*- coding: utf-8 -*-

miquire :core, 'messageconverters'
miquire :addon, 'addon'
miquire :addon, 'settings'
miquire :core, 'userconfig'

class Bitly < MessageConverters
  USER = 'mikutter'
  APIKEY = 'R_70170ccac1099f3ae1818af3fa7bb311'
  def user
    if UserConfig[:bitly_user] == '' or not UserConfig[:bitly_user]
      USER
    else
      UserConfig[:bitly_user]
    end end

  def apikey
    if UserConfig[:bitly_apikey] == '' or not UserConfig[:bitly_apikey]
      APIKEY
    else
      UserConfig[:bitly_apikey]
    end end

  def shrinked_url?(url)
    Regexp.new('http://(bit\\.ly|j\\.mp)/') === url end

  def shrink_url(urls)
    query = "version=2.0.1&login=#{user}&apiKey=#{apikey}&" + urls.map{ |url|
      "longUrl=#{Escape.query_segment(url).to_s}" }.join('&')
    3.times{
      result = begin
                 JSON.parse(Net::HTTP.get("api.bit.ly", "/shorten?#{query}"))
               rescue JSON::ParserError
                 nil
               end
      p result
      return Hash[ *result['results'].map{|pair| [pair[0], pair[1]['shortUrl']] }.flatten ] if result
      sleep(1) }
    nil
  end end

module Addon
  class Bitly < Addon
    USER = 'mikutter'
    APIKEY = 'R_70170ccac1099f3ae1818af3fa7bb311'
    include SettingUtils

    def onboot(watch)
      Plugin::Ring::fire(:plugincall, [:settings, watch, :regist_tab, self.main(watch), 'bit.ly'])
    end

    def main(watch)
      box = Gtk::VBox.new(false, 8)
      ft = gen_accountdialog_button('bit.ly アカウント設定',
                                    :bitly_user, 'ユーザ名',
                                    :bitly_apikey, 'APIキー'){ |user, pass|
        if(user == pass and user == '')
          true
        else
          query = "/v3/validate?x_login=#{user}&x_apiKey=#{pass}&apiKey=#{APIKEY}"+
            "&login=#{USER}&format=json"
          begin
            result = JSON.parse(Net::HTTP.get("api.bit.ly", query))
            result['data']['valid'] == '1'
          rescue JSON::ParserError
            nil
          end end }
      box.closeup(ft)
      return box
    end

  end
end

Plugin::Ring.push Addon::Bitly.new,[:boot]