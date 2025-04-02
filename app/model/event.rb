# frozen_string_literal: true

# == Schema Information
#
# Table name: events
#
#  id                   :bigint           not null, primary key
#  access               :text
#  address              :string(255)
#  application          :string(255)
#  calendar_start_date  :datetime
#  category             :integer          default("education")
#  content              :text
#  display_end_date     :datetime
#  event_tag            :integer
#  facebook             :string(255)
#  inquiry_email        :string(255)
#  inquiry_phone_number :string(255)
#  instagram            :string(255)
#  lat                  :decimal(, )
#  line                 :string(255)
#  lng                  :decimal(, )
#  manager              :string(255)
#  map_start_date       :datetime
#  name                 :string(255)
#  note                 :text
#  pdf_info             :string
#  period               :string(255)
#  period_note          :string(255)
#  point                :integer          default(0)
#  post_code            :string(255)
#  progress             :integer          default("published")
#  qr_start_datetime    :datetime
#  sdgs_content         :string(400)
#  sponsor              :text
#  status               :integer          default("active")
#  town                 :text
#  twitter              :string(255)
#  url                  :string(255)
#  water_station        :boolean          default(FALSE)
#  created_at           :datetime         not null
#  updated_at           :datetime         not null
#  active_area_id       :integer
#  city_id              :integer
#  prefecture_id        :integer
#  user_id              :bigint
#
# Indexes
#
#  index_events_on_user_id  (user_id)
#
class Event < BaseActiveRecord
    CHECKIN_TYPE = "checkin"
    RECEIVE_TYPE = "receive"
    EXCHANGE_TYPE = "exchange"
  
    # upload
    mount_uploader :pdf_info, PdfUploader
  
    # validate
    include Validations::Event
  
    # relationship
    has_many :event_images, dependent: :destroy
    has_many :event_checkins, dependent: :destroy
    has_many :users, through: :event_checkins
    has_many :sdg_experiences, as: :experienceable, dependent: :destroy
    has_many :event_point_exchanges, dependent: :destroy
    has_many :event_sdgs, dependent: :destroy
    has_many :sdgs, through: :event_sdgs
    has_many :activity_logs, as: :activitiable, dependent: :destroy
    has_many :qr_codes, as: :qr_codeable, dependent: :destroy
    belongs_to :active_area
    has_many :dashboard_events, dependent: :destroy
    has_many :transactions, dependent: :destroy
    has_many :user_event_exchanges, through: :event_point_exchanges
    reverse_geocoded_by :lat, :lng
  
    # callbacks
    after_save :create_transactions
  
    # nested_attributes
    accepts_nested_attributes_for :event_sdgs, :event_point_exchanges, :event_images,
                                  allow_destroy: true
  
    def create_transactions
      return unless (saved_change_to_progress? && progress_published?) ||
                    (new_record? && progress_published?)
  
      SaveTransactionService.new(nil, self.class.name, self).new_record
    end
  
    # enum
    enum status: {
      inactive: 0,
      active: 1
    }, _prefix: true
  
    enum category: {
      education: 0,
      festival: 1,
      sport: 2,
      culture: 3,
      health: 4,
      consultation: 5,
      other: 6
    }, _prefix: true
  
    enum progress: {
      draft: 0,
      published: 1,
      closed: 2
    }, _prefix: true
  
    # Scope
    scope :find_record, ->(id) {
                          where(id: id, status: "active", progress: "published")
                        }
  
    scope :check_time_map_display, -> {
      where('(map_start_date is null or map_start_date <= ?) and (display_end_date is null or display_end_date >= ?)', Time.current, Time.current)
    }
  
    scope :event_by_month, ->(year, month) {
      start_of_month = DateTime.new(year, month).beginning_of_month
      end_of_month = DateTime.new(year, month).end_of_month
      current_time = Time.current.in_time_zone('UTC')
  
      if start_of_month <= current_time && current_time <= end_of_month
        where('(qr_start_datetime is null or qr_start_datetime <= ?) AND (display_end_date is null or display_end_date >= ?)', current_time, current_time)
      else
        where('(qr_start_datetime is null or qr_start_datetime <= ?) AND (display_end_date is null or display_end_date >= ?)', end_of_month, start_of_month)
      end
    }
  
    scope :chart_with_month, -> {
      select("to_char(events.created_at::TIMESTAMP AT TIME ZONE 'UTC' AT TIME ZONE 'Asia/Tokyo', 'YYYY/MM') as column_chart, count(events.id) as value_chart")
        .group("column_chart")
        .order("column_chart")
    }
  
    scope :chart_with_year, -> {
      select("to_char(events.created_at::TIMESTAMP AT TIME ZONE 'UTC' AT TIME ZONE 'Asia/Tokyo', 'YYYY') as column_chart, count(events.id) as value_chart")
        .group("column_chart")
        .order("column_chart")
    }
  
    scope :top20_with_checkin_count, -> {
      select("events.id, events.name, events.town as address, COUNT(distinct event_checkins) as check_in_count")
        .left_joins(:event_checkins)
        .group("events.id")
        .order(check_in_count: :desc)
        .limit(20)
    }
  
    # ransacker
    ransacker :status, formatter: proc { |key| statuses[key] }
    ransacker :category, formatter: proc { |key| categories[key] }
    ransacker :progress, formatter: proc { |key| progresses[key] }
  
    def pdf_info_url
      generate_cloudfront_url(pdf_info)
    end
  
    def tag
      ActiveAreaTag.find_by(id: event_tag)
    end
  end
  