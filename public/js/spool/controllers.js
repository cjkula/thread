var spoolApp = angular.module('spoolApp', []);

function getKeys() {
  var keys = localStorage.getItem('thread_keys');
  return keys ? JSON.parse(keys) : [];
}

function getKeyByBase58(base58) {
  return _.find(getKeys(), { 'base58': base58 });
}

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

spoolApp.controller('UserCtrl', ['$scope', '$http',
  function($scope, $http) {
    var addresses = _.map(getKeys(), 'base58').join(',');

    $http.get('/api/identities.json').success(
      function(response) {
        var identities = $scope.identities = response,
            uids = _.uniq(_.pluck(identities, 'root'));
        console.log(identities);
        console.log(uids);
      });

    $scope.bob = {
      handle: 'JoeBob1',
      fullName: 'Joe Bob Briggs',
      description: 'King of all rewritable media',
      avatar: 'avatars/joebob.jpg'
    };
    $scope.mary = {
      handle: 'MaryJane2',
      fullName: 'Mary Jane Paul',
      description: 'Cleaning all the things since 2009',
      avatar: 'avatars/maryjane.jpg'
    };
    $scope.following = [$scope.bob];
    $scope.notFollowing = [$scope.mary];
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
