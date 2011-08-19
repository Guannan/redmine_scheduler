class Booking < ActiveRecord::Base
  belongs_to :timeslot
  validates_presence_of :name, :phone, :email
  validates_length_of :name, :email, :maximum => 127
  validates_length_of :phone, :maximum => 16
  validates_length_of :project_desc, :maximum => 1024
  
end
