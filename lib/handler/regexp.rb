# frozen_string_literal: true

require_relative '../sitesettinghandler'

class RegexpMulti < SiteSettingHandler
  def match(source)
    /#{@value}/m.match(source)
  end
  add_handler
end
