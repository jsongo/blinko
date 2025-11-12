import EventEmitter from "events";

export const eventBus = new EventEmitter();

// Increase max listeners since we may have multiple editor instances
eventBus.setMaxListeners(20);