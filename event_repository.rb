# frozen_string_literal: true

class EventRepository < Ibrain::BaseRepository
  include InvalidRelationCheck

  # Initialize a new EventRepository instance
  # @param record [Event, nil] The event record to operate on (optional)
  # @return [EventRepository] A new instance of EventRepository
  def initialize(current_user, record = nil)
    super(current_user, record)
  end

  # Save event with its related attributes
  # @raise [InvalidRelationError] When related entities have invalid format
  # @return [Event] The saved event record
  def save(attributes)
    # Check invalid relations
    relations_name = ["event_sdgs", "event_images"]
    raise_invalid_relation(attributes, relations_name)
    update(attributes)

    record
  end

  # Update event with the given attributes
  # @note Skip validation if progress is 'draft'
  # @return [Event] The updated event record
  def update(attributes)
    # Monitor performance with ProfilerService
    ProfilerService.profile_and_notify do
      record.assign_attributes(attributes)
      record.save!(validate: attributes[:progress] != 'draft')
    end
  end

  # Find an event by ID with permission check
  # @raise [PermissionError] When user doesn't have permission to access the event
  # @return [Event] The found event
  def find(args)
    event = Event.find args[:id]
    permission_admin = current_user.permission&.code
    if current_user.role_admin? && (permission_admin == ("AD_EVT" || "AD_DLC_SPT_EVT") && event.active_area_id != current_user.active_area_id)
      raise IbrainErrors::PermissionError.new(I18n.t("errors.messages.permission_denied", field_name: "event"))
    end

    event
  end

  # Delete an event
  def destroy
    record.destroy!
  end

  # Event summary statistics
  # @return Summary data including counts and charts
  def summarize(args)
    area_id = args[:active_area_id]
    args[:where]

    {
      new_event_count: Event.ransack({ active_area_id_eq: area_id }).result.count,
      new_event_chart: ChartService.new(Event, args).perform,
      event_checkin_chart: ChartService.new(EventCheckin, args).perform,
      event_exchange_chart: ChartService.new(EventPointExchange, args).perform
    }
  end

  # Get top events by checkin count
  def top_event(args)
    Event.top20_with_checkin_count.ransack(args[:where]).result
  end

  # Generate general CSV report for events
  def general(args)
    EventCsv.new(args).general
  end

  class << self
    # Find an event for client view with published status check
    # @raise [GraphQL::ExecutionError] When event not found or not published
    # @return Event for client
    def find_client(args)
      event = Event.status_active.progress_published.find_by(id: args[:id])
      return event if event.present?

      raise GraphQL::ExecutionError, I18n.t("errors.messages.occurred_error")
    end

    # Aggregate events with filtering, sorting and pagination
    # @return [ActiveRecord::Relation] Collection of events
    def aggregate(args)
      # Monitor performance with ProfilerService
      ProfilerService.profile_and_notify do
        where_condition = args[:where]
        column = args[:column]
        direction = args[:direction]
        Event.ransack(where_condition).result(distinct: true).order("#{column} #{direction}")
      end
    end

    # Aggregate events by location or time period
    def aggregate_by_location(args)
      args_month = args[:month]
      args_year = args[:year]
      args_where = args[:where]

      if args[:lat].present? && args[:lng].present?
        events = event_by_location(args)
      elsif args_year.present? && args_month.present?
        events = Event.event_by_month(args_year, args_month).ransack(args_where).result(distinct: true)
      else
        events = Event.check_time_map_display.ransack(args_where).result(distinct: true)
      end

      events
    end

    # Add points to an event
    # @return [Hash] Success status of the operation
    def add_point(args)
      event_id = args[:event_id]
      active_area_id = args[:active_area_id]

      AddPointEventJob.perform_later(event_id, active_area_id, args[:point].to_i)

      { success: true }
    end

    private

      # Find events near a specific location use near method of geocoder gem
      # @return [ActiveRecord::Relation] Collection of events near the location
      def event_by_location(args)
        Event.check_time_map_display.ransack(args[:where]).result.near([args[:lat], args[:lng]], 10, units: :km)
      end
  end
end
