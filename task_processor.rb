class TaskProcessor

  @task_queue

  @workers_count # thread count

  @workers

  @exit_flag

  def add_task(task)
    @task_queue << task
  end

  def start
    @workers_count.times do |n|
      @workers << Thread.new(n+1) do |thread_n|
        # TODO task 추가되는 속도보다 소비되는 속도가 빠르다면 얘기치 않게 @task_queue.emtpy 가 될 수 있음.
        while !@exit_flag or !@task_queue.empty?

          while (task = @task_queue.shift(true) rescue nil) do
            #$logger.info('task by %s : %s' % [thread_n, Thread.current.object_id])
            begin
              task.call
            rescue
              $logger.warn "task exception occurred : #{$!}"
            end
            #task[:result] = "done by worker ##{thread_n} (in #{delay})"
          end

          # TODO 무한 루프를 막기 위한 것이지만, 최대 성능을 발휘하기에 좋은 방법은 아니다.
          # TODO 무잠금 방법으로 개선할 필요가 있다. (CountDownLatch? Semaphore? or See Java Concurrency Book)
          delay = rand(0)
          sleep delay
        end
      end
    end
  end

  def join
    @exit_flag = true
    @workers.each(&:join)
  end

  # constructor
  def initialize(workers_count)
    @task_queue = Queue.new
    @workers_count = workers_count != nil ? workers_count : number_of_processors
    @workers = []
    @exit_flag = false
  end

end
