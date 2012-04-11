require_dependency 'user'

# Patches Redmine's Users dynamically.  Adds a relationship User +has_and_belongs_to_many+ Skill. 
module UserPatch
  def self.included(base) # :nodoc:
    base.extend(ClassMethods)

    base.send(:include, InstanceMethods)

    # Same as typing in the class 
    base.class_eval do
      unloadable # Send unloadable so it will not be unloaded in development
      has_and_belongs_to_many :skills
      belongs_to :wage
      has_one :workgroup, :class_name => "Group",
        :foreign_key => "manager_id"

    end

  end

  module ClassMethods

  end

  module InstanceMethods

  end
end

# Add module to User
User.send(:include, UserPatch)
