class BookingsController < ApplicationController
  unloadable
  before_filter :find_timeslots, :only => [:new, :create]
  before_filter :find_booking, :only => [:show, :edit]

  def index
    @bookings = Booking.all
    
    #code block used for search form
    @time = []

    for i in 0..23 do
      for j in 0..3 do
        @time << [DateTime.new(2012, 1, 1, i, j * 15, 0).strftime("%H:%M:%S")]  #need to fix this
      end
    end
  end

  def new
    #@booking = Booking.new
    @bookings = Booking.all
    same_day(@timeslots)
    same_issue(@timeslots)
  end

  def create
    @booking = Booking.new(params[:booking])
    @booking.timeslots << @timeslots

    respond_to do |format|
      if @booking.save
        flash[:notice] = 'Booking was successfully created.'
        format.html { redirect_to :action => "index" }
        format.xml  { render :xml => @booking, :status => :created,
                    :location => @booking }
      else                                               
        flash[:warning] = 'Invalid Options... Try again!'
        format.html { redirect_to :action => "new" }
        format.xml  { render :xml => @booking.errors,
                    :status => :unprocessable_entity }
      end
    end
  end

  def show
  end

  def edit
  end

  private

  def same_issue(timeslots)
    same_issue = true
    issue_id = timeslots.first.issue_id

    timeslots.each do |timeslot|
      if (timeslot.issue_id != issue_id)
        same_issue = false
        break
      end
    end
    if same_issue == false
      flash[:warning] = "timeslots need to on the same issue"
      redirect_to :controller => 'timeslots', :action => 'find'
    end
  end

  def same_day(timeslots)
    same_date = true
    date = timeslots.first.slot_date

    timeslots.each do |timeslot|
      if (timeslot.slot_date != date)
        same_date = false
        break
      end
    end
    if same_date == false
      flash[:warning] = "timeslots need to on the same day"
      redirect_to :controller => 'timeslots', :action => 'find'
    end
  end

  def find_timeslots
    if params[:slot_ids].present?
      @timeslots = params[:slot_ids].map {|id| Timeslot.find(id)}
    else
      flash[:warning] = 'Cannot make a new Booking without some timeslots. Pick some here and click "Book..."'
      redirect_to :controller => 'timeslots', :action => 'find'
    end

    if @timeslots.detect {|slot| slot.booked?}
      flash[:warning] = 'One or more timeslots is already booked. Please select available slots here and click "Book..."'
      redirect_to :controller => 'timeslots', :action => 'find'
    end
  end

  def find_booking
    if params[:id].present?
      @booking = Booking.find(params[:id])
    else
      flash[:warning] = 'No ID specified.'
      redirect_to :action => 'index'
    end
  end
end
