# Patches Redmine's Users dynamically.  Adds a relationship User +has_and_belongs_to_many+ Skill. 
module UserPatch
  def self.included(base) # :nodoc:
    base.extend(ClassMethods)

    base.send(:include, InstanceMethods)

    # Same as typing in the class 
    base.class_eval do
      unloadable # Send unloadable so it will not be unloaded in development
      #has_and_belongs_to_many :skills
      has_many :levels
      has_many :skills, :through => :levels
      belongs_to :wage
      has_many :workgroups, :class_name => "Group",
        :foreign_key => "manager_id"
      has_many :time_entries
      has_many :timesheets

    end

  end

  module ClassMethods

  end

  module InstanceMethods
    def analyze_time(hours)
      c = 0.0
      b = self.time_entries.sort_by_date.reverse.take_while do |m|
        c += m.hours
        c <= hours
      end
      return b
    end
    
    def get_workload(weeks_back)
      self.time_entries.sort_by_date.after(Date.today - weeks_back.weeks)
    end
    
    def get_open_slots_by_date_range(from, to)
      slots = []
      Issue.lcshift.from_date(from).until_date(to).foruser(self).each do |issue|
        slots += issue.open_slots
      end
      return slots
    end
  end
end

