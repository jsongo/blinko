import ReactDOM from "react-dom/client";
import App from "./App";
import "./styles/globals.css";

// Unregister all service workers in development
if (import.meta.env.DEV) {
  navigator.serviceWorker?.getRegistrations().then((registrations) => {
    registrations.forEach((registration) => {
      registration.unregister();
      console.log('Service Worker unregistered:', registration);
    });
  });
}

ReactDOM.createRoot(document.getElementById("root") as HTMLElement).render(
  <App />
);
