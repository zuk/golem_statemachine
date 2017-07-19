
$gemspec = Gem::Specification.new do |s|
  s.name     = 'golem_statemachine'
  s.version  = '1.1.1'
  s.authors  = ["Matt Zukowski"]
  s.email    = ["matt@roughest.net"]
  s.homepage = 'http://github.com/zuk/golem_statemachine'
  s.platform = Gem::Platform::RUBY
  s.summary  = %q{Adds finite state machine behaviour to Ruby classes.}
  s.description  = %q{Adds finite state machine behaviour to Ruby classes. Meant as an alternative to acts_as_state_machine/AASM.}

  s.files  = `git ls-files`.split("\n")
  s.test_files = `git ls-files -- spec`.split("\n")

  s.require_path = "lib"

  s.extra_rdoc_files = ["README.rdoc", "MIT-LICENSE"]

  s.add_dependency("activesupport")

  s.rdoc_options = [
    '--quiet', '--title', 'Golem Statmeachine Docs', '--opname',
    'index.html', '--line-numbers', '--main', 'README.rdoc', '--inline-source'
  ]
end
