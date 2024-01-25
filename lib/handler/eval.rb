# frozen_string_literal: true

require_relative "../sitesettinghandler"

class EvalHandler < SiteSettingHandler
  def match(source)
    eval(@value, binding, parent&.path || "(nil)") # rubocop:disable Security/Eval
  end
  add_handler
end
