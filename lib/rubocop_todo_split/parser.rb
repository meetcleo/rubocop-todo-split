module RubocopTodoSplit
  Entry = Struct.new(:department, :cop, :lines, keyword_init: true)
  ParseResult = Struct.new(:entries, :file_header, keyword_init: true)

  class Parser
    COP_HEADER = /^([A-Z]\w+)\/(\w+):/

    def self.parse(source)
      new(source).parse
    end

    def initialize(source)
      @lines = source.lines
    end

    def parse
      entries = []
      file_header = []
      pending_comments = []
      current_entry = nil
      header_closed = false

      @lines.each do |line|
        if (match = COP_HEADER.match(line))
          header_closed = true
          entries << current_entry if current_entry
          current_entry = Entry.new(
            department: match[1],
            cop: "#{match[1]}/#{match[2]}",
            lines: pending_comments + [line]
          )
          pending_comments = []
        elsif line.start_with?(" ", "\t")
          current_entry&.lines&.<< line
        elsif !header_closed && current_entry.nil?
          # Before any cop — file header ends at the first blank line
          if line.strip.empty?
            header_closed = true
          else
            file_header << line
          end
        else
          # Root-level blank/comment between cops — pending for the next one
          pending_comments << line
        end
      end

      entries << current_entry if current_entry
      deduped = entries.reverse.uniq(&:cop).reverse
      ParseResult.new(entries: deduped, file_header: file_header)
    end
  end
end
