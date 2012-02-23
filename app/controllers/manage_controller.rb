class ManageController < ApplicationController #handles the management/rebooking of lab coach shifts. catch-all for staff functions. needs to be separated from the booking controller when we open up to patrons.
  unloadable
  include ManageHelper
  require 'prawn'
  before_filter :wage_check, :only => [:generate_timesheet, :timesheets]
  
  def index
    allbookings = Booking.all.select {|b| b.apt_time > DateTime.now} #all scheduled bookings in the future
    @booked = allbookings.select {|b| b.timeslot_id.present?} #all valid bookings
    nullified = allbookings.select {|b| b.timeslot_id.nil?} #all nullified bookings
    @orphaned = nullified.select {|b| b.cancelled.nil?} #all nullified bookings that weren't cancelled, must be rescheduled
    if @orphaned.present?
      flash[:warning] = 'There are ' + @orphaned.count.to_s + ' bookings to be rescheduled! Please address these to make this message go away!'
    end
    @cancelled = nullified.select {|b| b.cancelled == true} #intentionally cancelled bookings
    
    #Nightmare table sort! needs.. fire. sort_col is for active bookings, sort_o_col is for orphaned bookings, sort_c_col is for cancelled bookings.
    if params[:sort_col].present?
      case params[:sort_col].to_i
      when 0
        @booked = @booked.sort_by {|b| b.apt_time}
      when 1
        @booked = @booked.sort {|a, b| a.timeslot.coach.firstname.downcase <=> b.timeslot.coach.firstname.downcase}
      when 2
        @booked = @booked.sort_by {|b| b.name.downcase}
      when 3
        @booked = @booked.sort {|a, b| a.timeslot.issue_id <=> b.timeslot.issue_id}
      else
        @booked = @booked.sort_by {|b| b.apt_time}
      end
    end

    if params[:sort_o_col].present?
      case params[:sort_o_col].to_i
      when 0
        @orphaned = @orphaned.sort_by {|b| b.apt_time}
      when 2
        @orphaned = @orphaned.sort_by {|b| b.name.downcase}
      else
        @orphaned = @orphaned.sort_by {|b| b.apt_time}
      end
    end
    
    if params[:sort_c_col].present?
      case params[:sort_c_col].to_i
      when 0
        @cancelled = @cancelled.sort_by {|b| b.apt_time}
      when 2
        @cancelled = @cancelled.sort_by {|b| b.name.downcase}
      else
        @cancelled = @cancelled.sort_by {|b| b.apt_time}
      end
    end
  end

  def today #the "My shifts today page"
    @allshiftstoday = Issue.today.fdshift
    @todayshifts = @allshiftstoday.select {|i| i.assigned_to == User.current}
    @alllcshiftstoday = Issue.today.lcshift
    @todaylcshifts = @alllcshiftstoday.select {|i| i.assigned_to == User.current}
      
    #I bet this one will be enumerable because I use select...
    @mytasks = Issue.open.tasks.select {|i| i.assigned_to == User.current}
    @mygoals = Issue.open.goals.select {|i| i.assigned_to == User.current}

    #The Jason way, nice and clean but I can't seem to use stuff like #each on it, I think because its an array?
    #@mytasks = Issue.open.tasks.find_by_assigned_to_id(User.current.id)
    #@mygoals = Issue.open.goals.find_by_assigned_to_id(User.current.id)
    
    #The original way. Obviously an affront to God.
    #@mytasks = Issue.all.select {|i| ((i.tracker.name == "Task") && (i.status.is_closed == false)) && i.assigned_to == User.current}
    #@mygoals = Issue.all.select {|i| ((i.tracker.name == "Training Goal") && (i.status.is_closed == false)) && i.assigned_to == User.current}
  end
  
  def show #view a single booking
    @booking = Booking.find(params[:booking_id])
  end

  def cancel #cancel a booking (won't reschedule)
    @booking = Booking.find(params[:booking_id])
    unless @booking.timeslot_id.nil?
      @booking.project_desc = "[Original Staff Member: " + @booking.timeslot.coach.firstname + "] " + @booking.project_desc
    end
    @booking.timeslot_id = nil
    @booking.cancelled = true
    
     respond_to do |format|
       if @booking.save
         flash[:notice] = 'Booking cancelled. Timeslot should be available if one existed.'
         format.html { redirect_to :action => "index" }
         format.xml  { render :xml => @booking, :status => :cancelled,
                     :location => @booking }
       else                                               
         flash[:warning] = 'I canny cancel. Something is not right'
         format.html { redirect_to :action => "index" }
         format.xml  { render :xml => @booking.errors,
                     :status => :unprocessable_entity }
       end
    end
  end

  def schedule
  end
  
  def generate_timesheet
    @weekof = Date.parse(params[:weekof])
    name = User.current.firstname
    #wage = params[:wage]
    wage = User.current.wage.amount.to_s
    current = Date.today
    beginning = params[:weekof]

    usrtiments = TimeEntry.all.select {|t| t.user == User.current }

    @mon = (usrtiments.select {|t| t.spent_on == @weekof}).inject(0) {|sum, x| sum + x.hours}
    @tue = (usrtiments.select {|t| t.spent_on == (@weekof + 1)}).inject(0) {|sum, x| sum + x.hours}
    @wed = (usrtiments.select {|t| t.spent_on == (@weekof + 2)}).inject(0) {|sum, x| sum + x.hours}
    @thu = (usrtiments.select {|t| t.spent_on == (@weekof + 3)}).inject(0) {|sum, x| sum + x.hours}
    @fri = (usrtiments.select {|t| t.spent_on == (@weekof + 4)}).inject(0) {|sum, x| sum + x.hours}
    @sat = (usrtiments.select {|t| t.spent_on == (@weekof + 5)}).inject(0) {|sum, x| sum + x.hours}
    @sun = (usrtiments.select {|t| t.spent_on == (@weekof + 6)}).inject(0) {|sum, x| sum + x.hours}
    
    #@allshiftstoday = Issue.all.select {|i| (i.is_frontdesk_shift?) }
    #@todayshifts = @allshiftstoday.select {|i| (i.assigned_to == User.current) }
    #@alllcshiftstoday = Issue.all.select {|i| (i.is_labcoach_shift?) }
    #@todaylcshifts = @alllcshiftstoday.select {|i| (i.assigned_to == User.current) }

 #respond_to do |format|
    #  format.html
    #  format.pdf { render :pdf => generate_timesheet_pdf(name, wage, current, beginning, @mon, @tue, @wed, @thu, @fri, @sat, @sun) }
    #end
    
    send_data (generate_timesheet_pdf(name, wage, current, beginning, @mon, @tue, @wed, @thu, @fri, @sat, @sun),
      :filename => name + "_timecard_from_" + beginning.to_s + "_to_" + (@weekof + 6.days).to_s + ".pdf",
      :type => "application/pdf")
  end
  
  def timesheets
    if params[:date].present? #look for a year and set the current one if not present.
      @year = params[:date][:year]
    else
      @year = Time.current.year.to_s
    end
    
    #Find first monday
    days = []
    dcount = 0
    7.times do
      days << (Date.new(@year.to_i) + dcount.days)
      dcount += 1
    end
    yearstart = days.detect {|day| day.wday == 1 }
    
    @weeks = []
    c = 0
    52.times do
      @weeks << [(yearstart + c.weeks).strftime("Week of %B %d"), (c + 1)]
      c += 1
    end
    if params[:tweek].present?
      @tweek = params[:tweek]
    else
      @tweek = 1
    end

    @weekof = yearstart + (@tweek.to_i - 1).weeks
    usrtiments = TimeEntry.all.select {|t| t.user == User.current }
    @seltiments = usrtiments.select {|t| (t.tyear == @year.to_i) && (t.tweek == @tweek.to_i) }
    @entsbyday = []
    daycount = 0
    7.times do
      day = (@weekof + daycount.days)
      @entsbyday << @seltiments.select {|t| t.spent_on == day}
      daycount += 1
      
    end

    @totalhours = @seltiments.inject(0) {|sum,x| sum + x.hours}
    
  end
      
  private
  
  def wage_check
    unless User.current.admin?
      if User.current.wage.nil?
        flash[:warning] = "You don't seem to be assigned a wage. Please speak to your manager."
        redirect_to :action => 'today'
      end
    end
  end
end
