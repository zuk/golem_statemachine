require 'test_helper'
require File.dirname(__FILE__)+'/../examples/seminar'

# Test the seminar.rb example.
class SeminarTest < Test::Unit::TestCase

  def setup
    @seminar = Seminar.new
    Seminar.output = File.open("#{self.class.name}_#{self.method_name}.log", 'w')
  end

  def test_initial_status
    assert_equal :proposed, @seminar.statemachine.initial_state
  end

  def test_open_for_enrollment
    @seminar.max_class_size = 3

    @seminar.schedule
    @seminar.open

    assert_equal :open_for_enrollment, @seminar.status

    @seminar.enroll_student("socrates")
    @seminar.enroll_student("plato")

    assert_equal :open_for_enrollment, @seminar.status

    @seminar.drop_student("socrates")

    assert_equal :open_for_enrollment, @seminar.status
    assert_equal ["plato"], @seminar.students

    @seminar.enroll_student("aristotle")
    @seminar.enroll_student("socrates")

    assert_equal :full, @seminar.status

    @seminar.drop_student("plato")

    assert_equal :open_for_enrollment, @seminar.status
    assert_equal ["aristotle", "socrates"], @seminar.students

    @seminar.enroll_student("zeno")

    assert_equal :full, @seminar.status

    @seminar.cancel

    assert_equal :cancelled, @seminar.status
    @seminar.students.each do |student|
      assert @seminar.notifications_sent.include?("#{student}: the seminar has been cancelled")
    end
  end

  def test_full
    @seminar.max_class_size = 3

    @seminar.schedule
    @seminar.open
    
    @seminar.enroll_student("socrates")
    @seminar.enroll_student("plato")
    @seminar.enroll_student("aristotle")

    assert_equal :full, @seminar.status

    @seminar.enroll_student("zeno")
    
    assert_equal :full, @seminar.status
    assert_equal ["socrates", "plato", "aristotle"], @seminar.students
    assert_equal ["zeno"], @seminar.waiting_list

    @seminar.enroll_student("sofia")

    assert_equal :full, @seminar.status
    assert_equal ["socrates", "plato", "aristotle"], @seminar.students
    assert_equal ["zeno", "sofia"], @seminar.waiting_list

    @seminar.drop_student("socrates")

    assert_equal :full, @seminar.status
    assert_equal ["plato", "aristotle", "zeno"], @seminar.students
    assert_equal ["sofia"], @seminar.waiting_list

    @seminar.drop_student("aristotle")

    assert_equal :full, @seminar.status
    assert_equal ["plato", "zeno", "sofia"], @seminar.students
    assert_equal [], @seminar.waiting_list

    @seminar.enroll_student("dennett")

    assert_equal :full, @seminar.status
    assert_equal ["plato", "zeno", "sofia"], @seminar.students
    assert_equal ["dennett"], @seminar.waiting_list

    @seminar.cancel

    assert_equal :cancelled, @seminar.status
    (@seminar.students + @seminar.waiting_list).each do |student|
      assert @seminar.notifications_sent.include?("#{student}: the seminar has been cancelled")
    end
  end
end

