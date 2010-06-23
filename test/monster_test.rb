require 'test_helper'
require File.dirname(__FILE__)+'/../examples/monster'

# Because the Monster class has two statemachines ('affect' and 'mouth')
# this test allows for validating statemachine behaviour when there are
# multiple statemachines defined within the same class.
class MonsterTest < Test::Unit::TestCase

  def setup
    @monster = Monster.new
  end

  def test_initial_state
    assert_equal :sleeping, @monster.affect.initial_state
    assert_equal :closed, @monster.mouth.initial_state
  end

  def test_non_existent_event
    assert_raise(NoMethodError){@monster.dance!}
  end

  def test_machine_state_accessors
    assert_equal :sleeping, @monster.affect_state

    assert_equal :closed, @monster.mouth_state
  end
  
  def test_event_possibility_within_states
    assert_equal :sleeping, @monster.affect_state
    assert_equal :closed, @monster.mouth_state

    assert_raise(Golem::ImpossibleEvent){@monster.feed!}
    assert_raise(Golem::ImpossibleEvent){@monster.lullaby!}
    assert_nothing_raised{@monster.wake_up!}
    assert_equal :hungry, @monster.affect_state

    assert_raise(Golem::ImpossibleEvent){@monster.wake_up!}
    assert_nothing_raised{@monster.lullaby!}
    assert_equal :hungry, @monster.affect_state

    assert_raise(Golem::ImpossibleEvent){@monster.feed!(:hamburger)}
    assert_nothing_raised{@monster.tickle!}
    assert_nothing_raised{@monster.feed!(:hamburger)}
    assert_equal :satiated, @monster.affect_state

    assert_raise(Golem::ImpossibleEvent){@monster.feed!}
    assert_raise(Golem::ImpossibleEvent){@monster.wake_up!}
  end

  def test_transition_decisions
    @monster.wake_up!

    assert_equal :hungry, @monster.affect_state

    @monster.tickle!
    
    @monster.feed!(:toast) # monster doesn't care for toast

    assert_equal :hungry, @monster.affect_state
    assert @monster.deeds.include?(:ate_toast)
    assert !@monster.deeds.include?(:barfed)

    @monster.feed!(:tofu) # monster hates tofu

    assert @monster.deeds.include?(:barfed)
    assert_equal :hungry, @monster.affect_state

    @monster.feed!(:hamburger) # monster likes hamburger

    assert_equal :satiated, @monster.affect_state
    assert @monster.deeds.include?(:ate_tasty_hamburger)
  end

  def test_state_actions
    @monster.wake_up!

    assert_raise(Golem::ImpossibleEvent){@monster.wake_up!}
    assert_equal [:stretched, :grumbled], @monster.deeds
      # The transition didn't take place, so :hungry's enter action should not have been executed
      # (i.e. we should only see one :grumbled).

    @monster.tickle!
    @monster.feed!(:toast)
    @monster.lullaby!
    @monster.tickle!
    @monster.feed!(:tofu)

    assert_equal [:stretched, :grumbled, :giggled, :grumbled, :ate_toast, :grumbled, :yawned, :grumbled, :giggled, 
      :grumbled, :barfed, :grumbled], @monster.deeds
      # Note that `grumble` is executed even when we transition from :hungry back to :hungry.
      # Enter and exit actions are to be executed even for self-transitions, however they should NOT be executed when
      # transition fails to occur (i.e. when an ImpossibleEvent is raised).
  end

  def test_transition_actions
    @monster.wake_up!
    @monster.tickle!
    @monster.feed!(:toast)
    @monster.lullaby!
    @monster.tickle!
    @monster.feed!(:tofu)
    @monster.feed!(:hamburger)
    @monster.lullaby!
    @monster.lullaby!

    assert_equal [:stretched, :grumbled, :giggled, :grumbled, :ate_toast, :grumbled, :yawned, :grumbled, :giggled, 
                  :grumbled, :barfed, :grumbled, :ate_tasty_hamburger, :yawned], @monster.deeds
  end
end

