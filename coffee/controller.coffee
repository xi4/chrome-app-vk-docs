controller = angular.module "apps.controller", []
#TODO отвечает за окно отправки другу
controller.controller 'friendCtrl', [
  '$scope'
  '$modalInstance'
  'VkApi'
  '$rootScope'
  'logs'
  ($scope, $modalInstance, VkApi, $rootScope, logs)->
    $scope.friends = VkApi.getAllFriend()

    $scope.sel = (friend)->
      $scope.selected = friend.id
    $scope.send = ->
      if $scope.selected > 0
        $rootScope.$broadcast 'sendFriend', $scope.selected
        $modalInstance.close()
      else
        logs.message 'Ошибка', 'Друг не выбран', 'error'
    $scope.close = ->
      $modalInstance.close()
]
#TODO отвечает за окно настроек
controller.controller 'setCtrl', [
  '$scope'
  '$modalInstance'
  ($scope, $modalInstance)->
    chrome.storage.local.get 'selDir', (item)->
      if item
        chrome.fileSystem.isRestorable item.selDir, (isRes)->
          if isRes
            chrome.fileSystem.restoreEntry item.selDir, (dir)->
              chrome.fileSystem.getDisplayPath dir, (path)->
                $scope.selDir = path
                $scope.$digest()
    $scope.selectDir = ->
      chrome.fileSystem.chooseEntry
        type: 'openDirectory'
      , (dir)->
        if not dir
          $scope.selDir = "Папка для сохранения не выбрана"
        $scope.tempDir = chrome.fileSystem.retainEntry dir
        chrome.fileSystem.getDisplayPath dir, (path)->
          $scope.selDir = path
          $scope.$digest()
    $scope.save = ->
      chrome.storage.local.set
        selDir: $scope.tempDir
      $modalInstance.close()
      logs.message 'Внимание', 'Настройки были успешно сохранены', 'success'
    $scope.close = ->
      $modalInstance.close()
]
#TODO отвечает за загрузку файлов в документы ВКонтакте
controller.controller 'fileCtrl', ($scope, $rootScope, VkApi)->
  $scope.input = angular.element document.querySelector('.file')[0]
  $scope.openFileDialog = ->
    $scope.input.click()
  $rootScope.$on 'addFile', ->
    $scope.openFileDialog()
  $scope.input.onchange = (event)->
    $scope.files = Util.toArray event.target.files
    VkApi.sendFile $scope.files[0]

  new DnDFileController 'body', (files)->
    $scope.files = Util.toArray files
    VkApi.sendFile $scope.files[0]

  $rootScope.$on 'sendFile:false', (event, data) ->
    VkApi.sendFile data
  $rootScope.$on 'sendFile:true', ->
    $scope.files.splice 0, 1;
    VkApi.sendFile $scope.files[0] if $scope.files.length > 0
#TODO Отвечает за отображаение документов
controller.controller 'indexCtrl', [
  '$scope'
  '$rootScope'
  'VkApi'
  '$timeout'
  'logs'
  'utils'
  ($scope, $rootScope, VkApi, $timeout, logs, utils)->
    $scope.sortType = ''
    $scope.sortReverse = false
    $scope.searchFile = ''
    $scope.sizeFormat = utils.sizeFormat
    $scope.selectItem = []
    #todo функция отправки друзьям (надо переносить)
    $rootScope.$on 'sendFriend', (e, friend)->
      fileList = ''
      for i in [0...$scope.selectItem.length]
        fileList += 'doc' + $scope.selectItem[i].owner_id.toString() + '_' + $scope.selectItem[i].id.toString() + ','
      fileList = fileList.substr 0, fileList.length - 1
      VkApi.api 'messages.send',
        user_id: friend,
        attachment: fileList
      , (data)->
        if not data.error
          logs.success 'Внимание', 'Сообщение отправленно успешно', 'error'
    #todo работа с выделением файла
    $scope.addAction = (file)->
      if $scope.selectItem.indexOf(file) != -1
        $scope.selectItem.splice $scope.selectItem.indexOf(file), 1
        if $scope.selectItem.length == 0
          $rootScope.$broadcast 'selected', false
        else
          $rootScope.$broadcast 'selected', true
      else
        $scope.selectItem.push file
        $rootScope.$broadcast 'selected', true
    #todo добавляем обьект файла в список файлов
    $rootScope.$on 'addFile:data', (event, data)->
      $scope.items.push data
    #todo выделение файлов (надо перенести в сервисы)
    $rootScope.$on 'selectAll', ->
      if $scope.selectItem.length > 0
        $scope.selectItem = [];
        $rootScope.$broadcast 'selected', false
      else
        if $scope.searchFile.length == 0
          $rootScope.$broadcast 'selected', true
          $scope.selectItem = $scope.items
        else
          items = Util.toArray angular.element(document.querySelectorAll('tr[data-doc_id]'))
          items.forEach (data)->
            angular.forEach $scope.items, (file)->
              $scope.selectItem.push file if file.id == parseInt(data.getAttribute 'data-doc_id')
        $rootScope.$broadcast 'selected', true
    #todo удаление файлов
    $rootScope.$on 'del_file', (event, res)->
      if res == 1
        $scope.items.splice $scope.items.indexOf($scope.tempfile), 1
      if $scope.selectItem.length > 0
        $scope.tempfile = $scope.selectItem.splice(0, 1)[0]
        VkApi.delFile $scope.tempfile
      else
        $rootScope.$broadcast 'selected', false
    #TODO проверка на наличие авторизации
    chrome.storage.local.get 'access_token', (item)->
      if  item.access_token == '' || item.access_token == undefined
        VkApi.auth();
      else
        $rootScope.$broadcast 'access_token:true'
    #TODO получение события о успешной синхронизации
    $rootScope.$on 'access_token:true', ->
      VkApi.loadDocs()
      VkApi.loadFriend()
    #TODO получение события о успешной загрузке документов
    $rootScope.$on 'docsList:load', ->
      if  Util.toArray(angular.element(document.querySelectorAll('tr[data-doc_id]'))).length > 0
        $scope.items = VkApi.getAllDocs()
      else
        $scope.searchFile = ''
        $scope.items = VkApi.getAllDocs()

    #todo скачивает файлы
    $scope.download = (file)->
      utils.downloadFile file
]
#TODO навигация
controller.controller 'navCtrl', ($scope, $rootScope, $modal)->
  $scope.toggle = false;
  $scope.selected = false;
  $rootScope.$on 'selected', (event, data)->
    $scope.selected = data
  $scope.tog = ->
    $scope.toggle = !$scope.toggle
  $scope.addFile = ->
    $rootScope.$broadcast 'addFile'
  $scope.selectAllFile = ->
    $rootScope.$broadcast 'selectAll'
  $scope.deleteSelected = ->
    $rootScope.$broadcast 'del_file'
  $scope.sendFriend = ->
    friend = $modal.open
      templateUrl: 'tpl/friend.html',
      controller: 'friendCtrl'
  $scope.settings = ->
    modalInstance = $modal.open
      templateUrl: 'tpl/settings.html',
      controller: 'setCtrl'
  $scope.refresh = ->
    $rootScope.$broadcast 'access_token:true'