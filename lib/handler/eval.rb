# frozen_string_literal: true

require_relative '../sitesettinghandler'

class EvalHandler < SiteSettingHandler
  def match(source)
    eval(@value, binding, parent&.path || "(nil)")
  end
  add_handler
end
