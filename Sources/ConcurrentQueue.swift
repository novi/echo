#if os(Linux)
    import Glibc
#else
    import Darwin
#endif

final class ConcurrentQueue {
    let identifier: String
    
    var events: [() -> ()]
    
    var eventMutex: pthread_mutex_t
    
    var eventCondition: pthread_cond_t
    
    var loopThread: pthread_t
    
    init(identifier: String) {
        self.identifier = identifier
        self.events = []
        self.eventMutex = pthread_mutex_t()
        self.eventCondition = pthread_cond_t()
        #if os(Linux)
        self.loopThread = pthread_t()
        #else
        self.loopThread = pthread_t(nil)
        #endif
        run()
    }
}

extension ConcurrentQueue: DispatchQueue {
    
    func run() {
        let block = {
            var conditionMutex = pthread_mutex_t()
            
            pthread_mutex_init(&self.eventMutex, nil)
            
            pthread_mutex_init(&conditionMutex, nil)
            
            pthread_cond_init (&self.eventCondition, nil)
            
            pthread_mutex_lock(&conditionMutex)
            
            while true {
                while self.events.count > 0 {
                    pthread_mutex_lock(&self.eventMutex)
                    let event = self.events.removeFirst()
                    pthread_mutex_unlock(&self.eventMutex)
                    #if os(Linux)
                    var thread = pthread_t()
                    #else
                    var thread = pthread_t(nil)
                    #endif
                    self.runBlock(event, onThread: &thread)
                }
                pthread_cond_wait(&self.eventCondition, &conditionMutex)
            }
        }
        
        runBlock(block, onThread: &loopThread)
    }
    
}
