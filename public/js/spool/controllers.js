var spoolApp = angular.module('spoolApp', []);

angular.module('spoolApp').directive('ngEnter', function() {
        return function(scope, element, attrs) {
            element.bind("keydown keypress", function(event) {
                if(event.which === 13) {
                    scope.$apply(function(){
                        scope.$eval(attrs.ngEnter, {'event': event});
                    });

                    event.preventDefault();
                }
            });
        };
    });

spoolApp.controller('UserCtrl', ['$scope',
  function($scope) {
    $scope.bob = {
      handle: 'JoeBob1',
        fullName: 'Joe Bob Briggs',
      description: 'King of all rewritable media',
      rootAddress: '18XyNMz3oumDcHVqGgsiWei3DbKDWxv1C6',
        avatar: 'avatars/joebob.jpg'
    };
    $scope.mary = {
      handle: 'MaryJane2',
        fullName: 'Mary Jane Paul',
      description: 'Cleaning all the things since 2009',
      rootAddress: '18dx6ij2cMk4VdwEN5Hb8LTMdefz9QP9xW',
        avatar: 'avatars/maryjane.jpg'
    };
    $scope.identities = [$scope.bob, $scope.mary];
    $scope.user = $scope.bob;
  }]);

spoolApp.controller('PostCtrl', ['$scope',
  function($scope) {
    $scope.formatTime = function(timestamp) {
      return new Date(timestamp).toLocaleTimeString();
    };
    $scope.submitForm = function() {
      $scope.posts.unshift({
        text: $scope.text,
        author: $scope.user,
        timestamp: Date.now()
      });
      $scope.text = "";
    };
    $scope.posts = [
      {
        text: 'This just in',
        author: $scope.bob,
        timestamp: Date.now() - 20000
      },
      {
        text: "I am having a wonderful time, but I'd rather be mopping.",
        author: $scope.mary,
        timestamp: Date.now() - 30000
      },
      {
        text: 'If you get your tongue stuck in a mouse trap you will pronounce it mouth trap for a short period of time.',
        author: $scope.bob,
        timestamp: Date.now() - 40000
      }
    ]
  }]);
