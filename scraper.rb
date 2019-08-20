require 'nokogiri'
require 'pry-byebug'
require 'html2markdown'
# require 'active_support/all'

# url = "https://el.foundation/feed.xml"
# html = open(url)

rss = File.read('./src/feed.xml')
doc = Nokogiri::XML(rss)

class Post
  attr_reader :datestamp, :author

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

  def date
    Time.parse(@datestamp)
  end

  private

  def titleize(title)
    title.downcase.split(' ').map { |word| word.capitalize }.join(' ')
  end
end

posts = doc.xpath('//item')
posts[0,1].each do |post|
  obj = Post.new({
    title: post.at_css('title').text,
    author: post.css('dc|creator').text,
    datestamp: post.css('pubDate').text,
    body: post.css('content|encoded').text
  })

  puts "---"
  puts "title: #{obj.title}"
  puts "author: #{obj.author}"
  puts "date: #{obj.date}"
  puts "---\n\n"
  puts obj.body
end
