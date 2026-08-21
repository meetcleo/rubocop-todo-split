require "optparse"
require "pathname"
require "shellwords"
require "fileutils"

module RubocopTodoSplit
  class CLI
    TODO_FILE = ".rubocop_todo.yml"
    OUTPUT_DIR = "rubocop_todo"
    REGEN_CMD  = "rubocop --auto-gen-config --exclude-limit 9999 --no-auto-gen-timestamp"

    def self.start(argv)
      new(argv).run
    end

    def initialize(argv)
      @argv = argv
      @options = {
        path: ".",
        dry_run: false
      }
    end

    def run
      parse_options

      project_root = File.expand_path(@options[:path])
      todo_path    = File.join(project_root, TODO_FILE)
      output_dir   = File.join(project_root, OUTPUT_DIR)
      rubocop_path = File.join(project_root, ".rubocop.yml")

      if @options[:refresh]
        return run_refresh(project_root, todo_path, output_dir, @options[:refresh])
      end

      if @options[:regenerate]
        return 1 unless run_rubocop_regen(project_root)
      else
        unless File.exist?(todo_path)
          warn "#{TODO_FILE} not found in #{project_root}"
          return 1
        end
      end

      result = Parser.parse(File.read(todo_path))

      if result.entries.empty?
        warn "No cop entries found in #{todo_path}"
        return 1
      end

      writer = Writer.new(
        result.entries,
        file_header: result.file_header,
        output_dir: output_dir,
        dry_run: @options[:dry_run]
      )

      written = writer.write
      relative_paths = written.keys.sort.map { |p| Pathname.new(p).relative_path_from(project_root).to_s }

      report(written)

      writer.update_rubocop_yml(rubocop_path, relative_paths)
      action = @options[:dry_run] ? "Would update" : "Updated"
      puts "#{action} .rubocop.yml inherit_from"

      writer.rewrite_todo_yml(todo_path, relative_paths)
      action = @options[:dry_run] ? "Would rewrite" : "Rewrote"
      puts "#{action} #{TODO_FILE} with instructions"

      0
    end

    private

    def run_rubocop_regen(project_root, only: nil)
      cmd = "cd #{project_root.shellescape} && #{REGEN_CMD}"
      cmd += " --only #{only.shellescape}" if only
      puts "Running: #{cmd.sub(/.*&& /, "")}"
      return true if @options[:dry_run]

      system(cmd)

      todo_path = File.join(project_root, TODO_FILE)
      unless File.exist?(todo_path)
        warn "rubocop --auto-gen-config failed: #{TODO_FILE} was not created"
        return false
      end
      true
    end

    def run_refresh(project_root, todo_path, output_dir, department)
      split_file = File.join(output_dir, "#{department}.yml")

      # Clear the existing split file so rubocop generates a clean slate.
      # We can't delete it — .rubocop.yml lists it in inherit_from and rubocop
      # would fail to load a missing file. An empty file is loadable but has no
      # configuration, so rubocop treats all cops in this department as unconfigured.
      File.write(split_file, "") unless @options[:dry_run]

      return 1 unless run_rubocop_regen(project_root, only: department)

      unless File.exist?(todo_path)
        warn "#{TODO_FILE} not found after regen — nothing to refresh"
        return 1
      end

      result = Parser.parse(File.read(todo_path))
      entries = result.entries.select { |e| e.department == department }

      if entries.empty?
        puts "No offenses found for #{department} — nothing to write"
      else
        writer = Writer.new(
          entries,
          file_header: result.file_header,
          output_dir: output_dir,
          dry_run: @options[:dry_run]
        )
        written = writer.write
        report(written)
      end

      existing = File.exist?(todo_path) ? File.read(todo_path) : ""
      unless existing.include?("rubocop-todo-split")
        all_split_files = Dir[File.join(output_dir, "*.yml")]
          .map { |p| Pathname.new(p).relative_path_from(project_root).to_s }
          .sort
        stub_writer = Writer.new([], file_header: result.file_header, output_dir: output_dir, dry_run: @options[:dry_run])
        stub_writer.rewrite_todo_yml(todo_path, all_split_files)
        action = @options[:dry_run] ? "Would restore" : "Restored"
        puts "#{action} #{TODO_FILE} stub"
      end

      0
    end

    def parse_options
      OptionParser.new do |opts|
        opts.banner = "Usage: rubocop-todo-split [options]"

        opts.on("--path PATH", "Project root (default: current directory)") do |v|
          @options[:path] = v
        end

        opts.on("--regenerate", "Run rubocop --auto-gen-config then split (full regen)") do
          @options[:regenerate] = true
        end

        opts.on("--refresh DEPARTMENT", "Re-run rubocop for one department and update its split file") do |v|
          @options[:refresh] = v
        end

        opts.on("--dry-run", "Print what would be written without writing") do
          @options[:dry_run] = true
        end

        opts.on("-v", "--version", "Print version") do
          puts RubocopTodoSplit::VERSION
          exit 0
        end

        opts.on("-h", "--help", "Print this help") do
          puts opts
          exit 0
        end
      end.parse!(@argv)
    end

    def report(written)
      action = @options[:dry_run] ? "Would write" : "Wrote"
      written.keys.sort.each { |path| puts "#{action} #{path}" }
      puts ""
    end
  end
end
