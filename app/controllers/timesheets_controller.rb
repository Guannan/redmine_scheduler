class TimesheetsController < ApplicationController
  unloadable
  #respond_to :json   #what does this mean?
  include TimesheetHelper
  require "prawn"   #needed for pdf generation
  before_filter :require_admin, :only => [:manager_index, :manager_edit]

  def index
    @timesheets = Timesheet.all.paginate(:page => params[:timesheet_page], :per_page => 3)

  end

  #sorted the timesheets according to their 'weekof' attribute, only this seems to make sense right now.
  #why is it not sorting correctly??!
  def employee_index
    timesheets = Timesheet.all.select {|x| x.user_id == User.current.id}
    @not_submitted_ts = timesheets.select {|x| x.submitted == nil}.paginate(:page => params[:not_submitted_ts_page], :per_page => 5, :order => '#{weekof.cweek}')
    @submitted_ts = timesheets.select {|x| x.submitted != nil && x.paid == nil}.paginate(:page => params[:submitted_ts_page], :per_page => 5, :order => '#{weekof.cweek}')
    @paid_ts = timesheets.select {|x| x.paid != nil}.paginate(:page => params[:paid_ts_page], :per_page => 5, :order => '#{weekof.cweek}')

    #yearstart = find_first_monday(Time.current.year)
    #weekof = params[:cweek]
    user_entries = TimeEntry.all.select {|t| t.user == User.current}
    cur_week_entries = user_entries.select {|t| (t.tyear == Time.current.year) && (t.tweek == params[:weekof])}  #replace with cweek and cwyear
    @hours_total = cur_week_entries.inject(0) {|sum,x| sum + x.hours}
  end

  def manager_index
    @submitted_ts = []
    @paid_ts = []

    if params[:submit_checkbox].present? && params[:paid_checkbox].present?
      @submitted_ts = Timesheet.all.select {|x| x.submitted != nil && x.paid == nil}
      @paid_ts = Timesheet.all.select {|x| x.paid != nil}
    elsif params[:paid_checkbox].present?
      @paid_ts = Timesheet.all.select {|x| x.paid != nil}
    elsif params[:submit_checkbox].present?
      @submitted_ts = Timesheet.all.select {|x| x.submitted != nil && x.paid == nil}
    else
      @display_setting = 0
    end

    @all_user_names = []
    User.all.each do |cur_user|
      @all_user_names << cur_user.firstname
    end
  end

  def new
    @pay_period = Date.parse(params[:pay_period])
    @user = User.current
    @time_entries = @user.time_entries
    @timesheet = Timesheet.new
  end

  def employee_new
    yearstart = find_first_monday(Time.current.year)

    @weeks = []
    (0..51).each do |i|
      @weeks << [(yearstart + i.weeks).strftime("Week of %B %d"), (i)]
    end

    #flash[:notice] = "all weeks? #{@weeks.inspect}"
    if params[:cweek].present?
      cweek = params[:cweek].to_i + 1  #need to add 1 here to get the week number right
    else
      cweek = Date.today.cweek
    end
    #flash[:notice] = "cweek is #{@cweek.inspect}"
    @weekof = yearstart + (cweek - 1).weeks
    #@weekof = yearstart + (Date.today.cweek-1).weeks     #.weeks acts like *7
    user_entries = TimeEntry.all.select {|t| t.user == User.current}
    cur_week_entries = user_entries.select {|t| (t.tyear == Time.current.year) && (t.tweek == Date.today.cweek)}  #replace with cweek and cwyear
  
    @entries_by_day = []

    (0..6).each do |i| 
      day = (@weekof + i.days)
      @entries_by_day << cur_week_entries.select {|t| t.spent_on == day}
    end
  end

  def create #make a new timesheet from user input

    yearstart = find_first_monday(Time.current.year)

    if params[:weekof].present?
      weekof = yearstart + params[:weekof].to_i.weeks
      #flash[:notice] = "weekof is #{weekof}"
      #weekof = find_first_monday(Time.current.year) + (Date.current.cweek - 1).weeks
    else
      weekof = yearstart + (Date.current.cweek - 1).weeks
    end

    timesheet = Timesheet.new(:user_id => User.current.id, :weekof => weekof)

    # respond_to do |format|
      if timesheet.save
        flash[:notice] = "Timesheet for the week starting on #{timesheet.weekof} was successfully created."
      else
        # flash[:notice] = "user id is #{timesheet.user_id} and weekof is #{timesheet.weekof}"                                               
        flash[:warning] = 'Invalid Options... Try again!'
      end
    # end
    redirect_to :action => 'employee_index'
  end

  def show
  end

  def print
    current_ts = Timesheet.find(params[:current_ts_id])
    if params[:weekof].present?
      weekof = Date.parse(params[:weekof])   
    else
      weekof = Date.today
    end
    name = User.current.firstname
    wage = User.current.wage.amount.to_s
    current = Date.today

    #TODO change the name of the default scopes on TimeEntry for dates, they need to express that the collection includes the dates indicated.
    usrtiments = TimeEntry.foruser(User.current).after(weekof).before(weekof + 6.days) #this use of before and after is cool

    mon = (usrtiments.select {|t| t.spent_on == weekof}).inject(0) {|sum, x| sum + x.hours}
    tue = (usrtiments.select {|t| t.spent_on == (weekof + 1)}).inject(0) {|sum, x| sum + x.hours} 
    wed = (usrtiments.select {|t| t.spent_on == (weekof + 2)}).inject(0) {|sum, x| sum + x.hours}
    thu = (usrtiments.select {|t| t.spent_on == (weekof + 3)}).inject(0) {|sum, x| sum + x.hours}
    fri = (usrtiments.select {|t| t.spent_on == (weekof + 4)}).inject(0) {|sum, x| sum + x.hours}
    sat = (usrtiments.select {|t| t.spent_on == (weekof + 5)}).inject(0) {|sum, x| sum + x.hours}
    sun = (usrtiments.select {|t| t.spent_on == (weekof + 6)}).inject(0) {|sum, x| sum + x.hours}

    hours = mon + tue + wed + thu + fri + sat + sun
    status =""

    #need to check for valid datetime instead of nil
    if current_ts.paid != nil
      status = "Paid"
    elsif current_ts.paid == nil && current_ts.submitted != nil
      status = "Submitted, but not paid"
    else
      status = "Not submitted and not paid"
    end

    if hours == 0 || hours > 100
      #flash[:warning] = 'You do not have any hours for the specified week!  Add hours to print a timecard.'
      flash[:warning] = 'Error, error! Either you are printing a timesheet with no need for payment or you got some wiring loose and logged too many hours.'
      redirect_to :action => 'employee_index'   #potential problem with this when admin uses it
    else  #method in timesheethelper
      send_data (generate_timesheet_pdf(name, wage, current, weekof, mon, tue, wed, thu, fri, sat, sun,status),
        :filename => name + "_timecard_from_" + weekof.to_s + "_to_" + (weekof + 6.days).to_s + ".pdf",
        :type => "application/pdf")
    end
  end

  def edit
    @year = Time.current.year

    yearstart = find_first_monday(@year)
    flash[:notice] = "checking first monday of the year! #{yearstart.inspect}"

    @weeks = []
  
    (0..51).each do |i|
      @weeks << [(yearstart + i.weeks).strftime("Week of %B %d"), (i)]
    end

    @weekof = yearstart + (Date.today.cweek-1).weeks     #.weeks acts like *7
    user_entries = TimeEntry.all.select {|t| t.user == User.current}
    cur_week_entries = user_entries.select {|t| (t.tyear == @year) && (t.tweek == Date.today.cweek)}  #replace with cweek and cwyear
  
    @entries_by_day = []

    (0..6).each do |i| 
      day = (@weekof + i.days)
      @entries_by_day << cur_week_entries.select {|t| t.spent_on == day}
    end
  end

  def update
    @timesheet = Timesheet.find (params[:id])
    @timesheet.update_attributes (params[:timesheet])
    flash[:notice] = "Timesheet has been updated"
    redirect_to @timesheet
  end

  def delete
    flash[:warning] = "Are you sure you want to delete this timesheet?"
    #@timesheet = Timesheet.all
    @timesheet = Timesheet.all.paginate(:page => params[:timesheet_page], :per_page =>2)
    # @timesheet.destroy
    # redirect_to :action => "index"
  end

  def sort_name   
    @timesheets = Timesheet.all.paginate(:page => params[:timesheet_page], :per_page =>2, :order => 'name')
  end

  private

   
  def sort_wage

  end
  
  def find_first_monday(year)
    t = Date.new(year, 1,1).wday     #checks which day (Mon = 1, Sun = 0) is first day of the year 
    if t == 0
      return Date.new(year, 1,2)
    elsif t == 1
      return Date.new (year, 1,1)
    else
      return Date.new (year, 1,(1+8-t))     #cases designed to return the first Monday of the year's date
    end
  end
end