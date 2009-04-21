$: << File.expand_path(File.dirname(__FILE__)+"/../lib")
require 'golem'


class Seminar
  attr_accessor :status
  attr_accessor :students
  attr_accessor :waiting_list
  attr_accessor :max_size

  def initialize
    @students = [] # list of students enrolled in the course
    @max_class_size = 5
  end

  def seats_available?
    @students.size < @max_class_size
  end

  def waiting_list_is_empty?
    @waiting_list.empty?
  end

  def student_is_enrolled?(student)
    @students.include? student
  end

  def add_student_to_waiting_list(student)
    @waiting_list << student
  end

  def create_waiting_list
    @waiting_list = []
  end

  def notify_waiting_list_that_enrollment_is_closed
    @waiting_list.each{|student| puts "#{student}: waiting list is closed!"}
  end

  def notify_students_that_the_seminar_is_cancelled
    (@students + @waiting_list).each{|student| puts "#{student}: the seminar has been cancelled!"}
  end  


  include Golem

  define_statemachine do
    state :proposed do
      on :schedule, :to => :scheduled
    end

    state :scheduled do
      on :open, :to => :open_for_enrollment
    end

    state :open_for_enrollment do
      on :close, :to => :closed_to_enrollment
      on :enroll_student do
        transition :if => :seats_available? do |seminar, student|
          seminar.students << student
        end
        transition :to => :full, :if => Proc.new{|seminar, student| not seminar.student_is_enrolled?} do |seminar, student|
          seminar.add_student_to_waiting_list(student)
        end
      end
    end

    state :full do
      on :move_to_bigger_classroom, :to => :open_for_enrollment
      on :drop_student do
        transition :to => :open_for_enrollment, 
          :if => Proc.new{|seminar, student| seminar.student_is_enrolled?(student) && seminar.waiting_list_is_empty?} do
            seminar.students.delete student
          end
        transition :if => :student_is_enrolled? do |seminar, student|
          seminar.students.delete student
          seminar.enroll_student! seminar.waiting_list.shift
        end
      end
      on :enroll_student do
        transition :if => :seats_available? do |seminar, student|
          seminar.students << student
        end
        transition :action => :add_student_to_waiting_list
      end
      on :close, :to => :closed_to_enrollment
      enter :create_waiting_list
    end

    state :closed_to_enrollment do
      enter :notify_waiting_list_that_enrollment_is_closed
    end

    state :cancelled do
      enter :notify_students_that_the_seminar_is_cancelled
    end

    # The 'cancel' event can occur in all states.
    all_states.each do |state|
      state.on :cancel, :to => :cancelled
    end

    initial_state :proposed
    current_state_from :status

    on_all_transitions Proc.new{|obj, event, transition, event_args| puts "Transitioning from #{transition.from.name.inspect} to #{transition.to.name.inspect}"}
  end
end


s = Seminar.new
s.schedule!
s.open!
s.enroll_student! "bobby"
puts s.inspect
s.enroll_student! "eva"
puts s.inspect
s.enroll_student! "sally"
puts s.inspect
s.enroll_student! "matt"
puts s.inspect
s.enroll_student! "karina"
puts s.inspect
s.enroll_student! "tony"
puts s.inspect
s.enroll_student! "rich"
puts s.inspect
s.enroll_student! "suzie"
puts s.inspect
s.enroll_student! "fred"
puts s.inspect
s.drop_student! "sally"
puts s.inspect
s.drop_student! "bobby"
puts s.inspect
s.drop_student! "tony"
puts s.inspect
s.drop_student! "rich"
puts s.inspect
s.drop_student! "eva"
puts s.inspect
