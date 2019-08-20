require 'nokogiri'
require 'pry-byebug'
require 'html2markdown'

class Post
  attr_reader :datestamp, :author

  SAFE_FILENAME_REGEX = /[^0-9a-z\s]/i

  def initialize(opts = {})
    @title     = opts[:title]
    @datestamp = opts[:datestamp]
    @author    = opts[:author]
    @body      = opts[:body]
  end

  def title
    titleize(@title)
  end

  def body_html
    # Make Markdown friendly
    @body.gsub('<div>', '<p>').gsub('</div>', "</p>\n")
  end

  def body
    HTMLPage.new(contents: body_html).markdown
  end

  def timestamp
    Time.parse(@datestamp)
  end

  def filename
    iso_8601 = timestamp.strftime("%Y-%m-%d")
    cleaned = title.downcase.gsub('&', 'and')
                            .gsub(SAFE_FILENAME_REGEX, '')

    parameterized = cleaned.split(' ').join('-')

    "#{iso_8601}-#{parameterized}.md"
  end

  def print
    puts "Filename: #{filename}\n\n"
    puts "---"
    puts "title: \"#{title}\""
    puts "author: \"#{author}\""
    puts "date: #{timestamp}"
    puts "---\n\n"
    puts body[0, 1000] + " [...]"
  end

  def export(target_dir)
    target_path = File.join(target_dir, filename)
    puts "Writing to #{target_path}"

    File.open(target_path, 'w') do |f|
      f << "---\n"
      f << "title: \"#{title}\"\n"
      f << "author: \"#{author}\"\n"
      f << "date: #{timestamp}\n"
      f << "---\n\n"
      f << body
    end
  end

  private

  def titleize(title)
    title.downcase.split(' ').map { |word| word.capitalize }.join(' ')
  end
end

class Converter
  attr_reader :source, :target, :opts

  def initialize(source, target, opts = {})
    @source = source
    @target = target
    @opts = opts
  end

  def convert
    rss = parse_rss(source)
    doc = Nokogiri::XML(rss)
    posts = doc.xpath('//item')

    # Clean target directory or create
    if Dir.exist?(target)
      puts "Deleting entries in target directory"
      FileUtils.rm_rf Dir.glob("#{target}/*")
    else
      FileUtils.mkdir(target)
    end

    generate_markdown(posts)
  end

  def dry_run?
    opts[:dry_run] == true
  end

  def verbose?
    opts[:verbose] == true
  end

  private

  def parse_rss(path)
    if URI.parse(path).scheme.nil?
      File.read(path)
    else
      open(path)
    end
  rescue URI::InvalidURIError
    raise "source must be a valid file path or URL"
  end

  def generate_markdown(posts)
    posts.each do |post|
      obj = Post.new({
        title: post.at_css('title').text,
        author: post.css('dc|creator').text,
        datestamp: post.css('pubDate').text,
        body: post.css('content|encoded').text
      })

      if dry_run?
        obj.print
      else
        obj.export(target)
      end
    end
  end
end


# Converter.new("./src/feed.xml", "./exports", dry_run: true).convert
Converter.new("./src/feed.xml", "./exports").convert
