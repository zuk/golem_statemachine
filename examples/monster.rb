$: << File.expand_path(File.dirname(__FILE__)+"/../lib")
require 'golem'

class Monster
  include Golem
  
  attr_accessor :deeds
  attr_accessor :journal

  def initialize
    @deeds = []
    @journal = []
  end

  def stretch
    @deeds << :stretched
  end

  def grumble
    @deeds << :grumbled
  end

  def yawn
    @deeds << :yawned
  end

  def barf
    @deeds << :barfed
  end

  def likes_food?(food)
    food == :hamburger
  end

  def hates_food?(food)
    food == :tofu
  end

  def is_tired?
    deeds.last == :yawned
  end

  def mouth_is_open?
    mouth_state == :open
  end

  def write_in_journal(event, transition, *args)
    @journal << event.name if event.kind_of?(Golem::Model::Event) && transition.kind_of?(Golem::Model::Transition)
  end

  # statemachine representing the Monster's affect (i.e. how it is feeling)
  define_statemachine :affect do
    initial_state :sleeping
    on_all_transitions :write_in_journal

    state :sleeping do
      on :wake_up, :to => :hungry
      exit :stretch
    end

    state :hungry do
      enter :grumble
      on :feed, :if => :mouth_is_open?, :guard_options => {:failure_message => "its mouth is not open"} do
        transition :to => :satiated do
          guard :likes_food?, :failure_message => "it does not like the food"
          action {|monster,food| monster.deeds << "ate_tasty_#{food}".to_sym}
        end
        transition :to => :self do
          guard :hates_food?, :failure_message => "it does not hate the food"
          action :barf
        end
        transition :to => :self do
          action {|monster,food| monster.deeds << "ate_#{food}".to_sym}
        end
      end
      on :lullaby, :action => :yawn
      on :tickle do
        action {|monster| monster.deeds << :giggled }
      end
    end

    state :satiated do
      on :lullaby do
        transition :to => :sleeping, :if => :is_tired?
        transition :to => :self, :action => :yawn
      end
    end
  end

  # secondary statemachine representing the Monster's mouth
  define_statemachine :mouth do
    initial_state :closed
    state :open do
      on :lullaby, :to => :closed
    end
    state :closed do
      on :tickle, :to => :open
    end
  end
end
