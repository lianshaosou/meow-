import Foundation
import Testing
@testable import MeowFeatures
import MeowData

@Test
@MainActor
func authViewModelSetsErrorForInvalidEmail() async {
    let vm = AuthViewModel(authService: InMemoryAuthService())
    vm.email = "bad-email"
    vm.password = "12345678"

    await vm.signInWithEmail()

    #expect(vm.isAuthenticated == false)
    #expect(vm.errorMessage == "Enter a valid email address.")
}

@Test
@MainActor
func authViewModelAuthenticatesWithValidEmail() async {
    let vm = AuthViewModel(authService: InMemoryAuthService())
    vm.email = "meow@example.com"
    vm.password = "strongpass"

    await vm.signInWithEmail()

    #expect(vm.isAuthenticated)
    #expect(vm.errorMessage == nil)
}
