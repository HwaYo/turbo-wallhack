require 'rubygems'
require 'capybara'
require 'dotenv'
require 'csv'

Dotenv.load

Capybara.run_server = false
Capybara.javascript_driver = :selenium
Capybara.default_driver = :selenium
Capybara.app_host = 'http://cafe.naver.com/specup.cafe'
Capybara.default_wait_time = 5

EMAIL_REGEX = /[\w+\-.]+@[a-z\d\-]+(\.[a-z]+)*\.[a-z]+/i

StudyInfo = Struct.new(:host, :link, :study_name, :contact, :date) do
  def to_a
    [host, link, study_name, contact, date]
  end
end

module Scraper
  class Toeicamp
    attr_reader :host
    attr_accessor :study_infos
    include Capybara::DSL

    def initialize
      @host = 'http://cafe.naver.com/specup.cafe'
      @study_infos = []
    end

    def write_info(info)
      CSV.open('data.csv', 'a') do |csv|
        csv << info.to_a
      end
    end

    def get_info(study_name, link)
      visit link

      main_frame = find('#cafe_main')
      return unless main_frame

      within_frame(main_frame) do
        text = page.text

        if text =~ EMAIL_REGEX
          study_info = StudyInfo.new
          study_info.contact = text.match(EMAIL_REGEX).to_s
          study_info.host = host
          study_info.link = link
          study_info.study_name = study_name
          study_info.date = find('div.tit-box > div.fr > table > tbody > tr > td.m-tcol-c.date').text

          study_infos << study_info
          p study_info.to_a.to_s

          write_info study_info
        end
      end
    end

    def get_article_links(link)
      visit link

      article_links = nil

      main_frame = find('#cafe_main')
      return unless main_frame

      within_frame(main_frame) do
        article_links = find('form[name=ArticleList]').all('.aaa > a').map do |link|
          [link.text, link[:href]]
        end
      end

      article_links.each do |study_name, article_link|
        begin
          get_info study_name, article_link
        rescue
          next
        end
      end

    end

    def execute
      visit host
      login

      pages = 1..20
      pages.each do |page|
        link = "http://cafe.naver.com/ArticleList.nhn?search.boardtype=L&search.menuid=1205&search.questionTab=A&search.clubid=15754634&search.totalCount=151&search.page=#{page}"
        get_article_links link
      end
    end

  private
    def login
      click_link '로그인'
      fill_in '아이디', with: ENV['naver_id']
      fill_in '비밀번호', with: ENV['naver_pw']
      click_button '로그인'
    end
  end
end

scraper = Scraper::Toeicamp.new
scraper.execute
