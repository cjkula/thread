var explorerControllers = angular.module('explorerControllers', []);

explorerControllers.controller('NavigationCtrl', ['$scope', '$location',
  function($scope, $location) {
    $scope.isCurrentPath = function(path) {
      return $location.path().indexOf(path) === 0;
    };
  }]);

explorerControllers.controller('TransactionListCtrl', ['$scope', '$http',
  function($scope, $http) {
    $http.get('/api/transactions.json').success(function(data) {
      $scope.transactions = data;
    });

    $scope.orderProp = 'uid';
  }]);

explorerControllers.controller('TransactionDetailCtrl', ['$scope', '$routeParams', '$http',
  function($scope, $routeParams, $http) {
    function splitInto(chunkSize, string) {
      return string.match(new RegExp('.{1,' + chunkSize + '}', 'g'));
    }
    $http.get('/api/transactions/' + $routeParams.uid + '.json').success(function(data) {
      $scope.transaction = data;
      $scope.rawRows = _.map(splitInto(32, data.raw), function(row) {
        return _.map(splitInto(8, row), function(word) { return splitInto(2, word) });
      });
    });
  }]);

explorerControllers.controller('NewTransactionFormCtrl', ['$scope', '$http', '$location',
  function($scope, $http, $location) {
    $scope.transaction = { input: {}, output: {} };
    $scope.submitForm = function() {
      var inputs = $scope.transaction.input.transactionUid ? [$scope.transaction.input] : [],
          outputs = $scope.transaction.output.script ? [$scope.transaction.output] : [],
          tx = {
            inputs: inputs,
            outputs: outputs
          };
      $scope.error = "";
      $http.post('/api/transactions.json', tx).then(function(response) {
        $location.path('/transactions/' + response.data.uid);
      }, function(response) {
        $scope.error = response.data.error;
      });
    };
  }]);

explorerControllers.controller('CoinListCtrl', ['$scope', '$http',
  function($scope, $http) {
    $http.get('/api/values.json').success(function(data) {
      $scope.outputs = data;
      $scope.sum = _.sum(data, 'value');
    });
  }]);

explorerControllers.controller('AssetListCtrl', ['$scope', '$http',
  function($scope, $http) {
    $http.get('/api/assets.json').success(function(data) {
      $scope.outputs = data;
    });
  }]);

explorerControllers.controller('DocumentListCtrl', ['$scope', '$http',
  function($scope, $http) {
    $http.get('/api/documents.json').success(function(data) {
      $scope.documents = data;
    });
  }]);

explorerControllers.controller('DocumentDetailCtrl', ['$scope', '$routeParams', '$http',
  function($scope, $routeParams, $http) {
    $http.get('/api/documents/' + $routeParams.uid + '.json').success(function(data) {
      $scope.document = data.str;
    });
  }]);

explorerControllers.controller('BlockListCtrl', ['$scope', '$http',
  function($scope, $http) {
    $scope.blocks = [];
    // $http.get('/api/blocks.json').success(function(data) {
      // $scope.outputs = data;
    // });
  }]);

function getKeys() {
  var keys = localStorage.getItem('thread_keys');
  return keys ? JSON.parse(keys) : [];
}

function getKeyByBase58(base58) {
  return _.find(getKeys(), { 'base58': base58 });
}

explorerControllers.controller('KeyListCtrl', ['$scope', '$http',
  function($scope, $http) {
    $scope.keys = getKeys();

    $scope.generateKey = function() {
      $http.get('/api/addresses/generate.json').success(function(data) {
        $scope.keys.push(data);
        localStorage.setItem('thread_keys', JSON.stringify($scope.keys));
      });
    };
  }]);

explorerControllers.controller('KeyDetailCtrl', ['$scope', '$routeParams',
  function($scope, $routeParams) {
    $scope.key = getKeyByBase58($routeParams.base58);
  }]);
