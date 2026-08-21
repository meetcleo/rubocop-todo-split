require_relative "lib/rubocop_todo_split/version"

Gem::Specification.new do |spec|
  spec.name = "rubocop-todo-split"
  spec.version = RubocopTodoSplit::VERSION
  spec.authors = ["Cleo"]
  spec.email = ["engineering@meetcleo.com"]

  spec.summary = "Split .rubocop_todo.yml into per-department YAML files"
  spec.description = <<~DESC
    Reads .rubocop_todo.yml and writes one YAML file per RuboCop department
    (Style, Layout, Metrics, etc.) so teams can tackle technical debt
    incrementally by category.
  DESC
  spec.homepage = "https://github.com/meetcleo/rubocop-todo-split"
  spec.license = "MIT"
  spec.required_ruby_version = ">= 2.7"

  spec.files = Dir["lib/**/*", "exe/*", "*.md", "*.gemspec"]
  spec.bindir = "exe"
  spec.executables = ["rubocop-todo-split"]
end
