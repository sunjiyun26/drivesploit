module Msf
class DBManager

class Service < ActiveRecord::Base
	include DBSave
	has_many :vulns, :dependent => :destroy
	has_many :notes, :dependent => :destroy
	belongs_to :host

	serialize :info
end

end
end

