# Rails Repository Pattern
Overview

The Repository Pattern provides an abstraction layer between domain logic and data access logic in Rails applications. It centralizes data access code and promotes separation of concerns.
Structure


App/
├── repositories/
│   ├── base_repository.rb
│   ├── event_repository.rb
│   └── connect_spot_repository.rb
└── models/
    ├── event.rb
    └── connect_spot.rb
