import Combine
import ComposableArchitecture
import Counter
import FavoritePrimes
import SwiftUI
import PrimeAlert
import WolframAlpha

struct AppState: Equatable {
  var count = 0
  var favoritePrimes: [Int] = []
  var loggedInUser: User? = nil
  var activityFeed: [Activity] = []
  var alertNthPrime: PrimeAlert? = nil
  var isNthPrimeButtonDisabled: Bool = false
  var isPrimeModalShown: Bool = false

  struct Activity: Equatable {
    let timestamp: Date
    let type: ActivityType

    enum ActivityType: Equatable {
      case addedFavoritePrime(Int)
      case removedFavoritePrime(Int)
    }
  }

  struct User: Equatable {
    let id: Int
    let name: String
    let bio: String
  }

  var favoritePrimesState: FavoritePrimesState {
    get {
      (self.alertNthPrime, self.favoritePrimes)
    }
    set {
       (self.alertNthPrime, self.favoritePrimes) = newValue
    }
  }
}

//struct Identified<A>: Identifiable {
//  var value: A
//  var id: AnyHashablea
//  init<B>(_ value: A, by hashable: KeyPath<A, B>) {
//
//  }
//}

enum AppAction: Equatable {
  case counterView(CounterViewAction)
  case offlineCounterView(CounterViewAction)
  case favoritePrimes(FavoritePrimesAction)

//  var counterView: CounterViewAction? {
//    get {
//      guard case let .counterView(value) = self else { return nil }
//      return value
//    }
//    set {
//      guard case .counterView = self, let newValue = newValue else { return }
//      self = .counterView(newValue)
//    }
//  }
//
//  var favoritePrimes: FavoritePrimesAction? {
//    get {
//      guard case let .favoritePrimes(value) = self else { return nil }
//      return value
//    }
//    set {
//      guard case .favoritePrimes = self, let newValue = newValue else { return }
//      self = .favoritePrimes(newValue)
//    }
//  }
}

extension AppState {
  var counterView: CounterViewState {
    get {
      CounterViewState(
        alertNthPrime: self.alertNthPrime,
        count: self.count,
        favoritePrimes: self.favoritePrimes,
        isNthPrimeButtonDisabled: self.isNthPrimeButtonDisabled,
        isPrimeModalShown: self.isPrimeModalShown
      )
    }
    set {
      self.alertNthPrime = newValue.alertNthPrime
      self.count = newValue.count
      self.favoritePrimes = newValue.favoritePrimes
      self.isNthPrimeButtonDisabled = newValue.isNthPrimeButtonDisabled
      self.isPrimeModalShown = newValue.isPrimeModalShown
    }
  }
}

import CasePaths

struct AppEnvironment {
  var counter: CounterEnvironment
  var favoritePrimes: FavoritePrimesEnvironment
  var offlineNthPrime: (Int) -> Effect<Int?>
}

let appReducer: Reducer<AppState, AppAction, AppEnvironment> = combine(
  pullback(
    counterViewReducer,
    value: \AppState.counterView,
    action: /AppAction.counterView,
    environment: { $0.counter }
  ),
  pullback(
    counterViewReducer,
    value: \AppState.counterView,
    action: /AppAction.offlineCounterView,
    environment: { CounterEnvironment(nthPrime: $0.offlineNthPrime) }
  ),
  pullback(
    favoritePrimesReducer,
    value: \.favoritePrimesState,
    action: /AppAction.favoritePrimes,
    environment: { $0.favoritePrimes }
  )
)

func activityFeed(
  _ reducer: @escaping Reducer<AppState, AppAction, AppEnvironment>
) -> Reducer<AppState, AppAction, AppEnvironment> {

  return { state, action, environment in
    switch action {
    case .counterView(.counter),
         .offlineCounterView(.counter),
         .favoritePrimes(.loadedFavoritePrimes),
         .favoritePrimes(.loadButtonTapped),
         .favoritePrimes(.saveButtonTapped),
         .favoritePrimes(.primeButtonTapped),
         .favoritePrimes(.nthPrimeResponse),
         .favoritePrimes(.alertDismissButtonTapped):
      break
    case .counterView(.primeModal(.removeFavoritePrimeTapped)),
         .offlineCounterView(.primeModal(.removeFavoritePrimeTapped)):
      state.activityFeed.append(.init(timestamp: Date(), type: .removedFavoritePrime(state.count)))

    case .counterView(.primeModal(.saveFavoritePrimeTapped)),
         .offlineCounterView(.primeModal(.saveFavoritePrimeTapped)):
      state.activityFeed.append(.init(timestamp: Date(), type: .addedFavoritePrime(state.count)))

    case let .favoritePrimes(.deleteFavoritePrimes(indexSet)):
      for index in indexSet {
        state.activityFeed.append(.init(timestamp: Date(), type: .removedFavoritePrime(state.favoritePrimes[index])))
      }

    }

    return reducer(&state, action, environment)
  }
}

struct ContentView: View {
  @ObservedObject var store: Store<AppState, AppAction>

  var body: some View {
    NavigationView {
      List {
        NavigationLink(
          "Counter demo",
          destination: CounterView(
            store: self.store.view(
              value: { $0.counterView },
              action: { .counterView($0) }
            )
          )
        )
        NavigationLink(
          "Offline counter demo",
          destination: CounterView(
            store: self.store.view(
              value: { $0.counterView },
              action: { .offlineCounterView($0) }
            )
          )
        )
        NavigationLink(
          "Favorite primes",
          destination: FavoritePrimesView(
            store: self.store.view(
              value: { $0.favoritePrimesState },
              action: { .favoritePrimes($0) }
            )
          )
        )
      }
      .navigationBarTitle("State management")
    }
  }
}
