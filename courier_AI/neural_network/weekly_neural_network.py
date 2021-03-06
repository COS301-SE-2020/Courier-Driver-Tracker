import numpy as np
import pandas as pd
import tensorflow as tf
import urllib.request as request
import matplotlib.pyplot as plt
from tensorflow import keras
from tensorflow.keras.callbacks import ModelCheckpoint
import data.db_management as db


class NeuralNetwork:
    def __init__(self):
        self.model_path = 'models/WeeklyModel'
        self.checkpoint = ModelCheckpoint(
            self.model_path,
            monitor="val_acc",
            verbose=1,
            mode="max",
            save_best_only=True,
            save_weights_only=False,
            period=1
        )
        self.db_manager = db.DBManagement()
        self.initialise()

    def initialise(self):
        self.model = keras.Sequential([
            keras.layers.Dense(units=35, input_shape=(5, 7)),  # input layer (1)tr
            keras.layers.Flatten(),
            keras.layers.Dense(128, activation='relu'),  # hidden layer (2)
            keras.layers.Dense(128, activation='relu'),
            keras.layers.Dense(4, activation='softmax')  # output layer (4)

        ])
        self.exportNN()

    def importNN(self):
        self.model = keras.models.load_model(self.model_path)

    def exportNN(self):
        self.model.save(self.model_path)

    def train(self):

        trainX = np.asarray(self.getTrainingInputData())
        trainY = np.asarray(self.getTrainingOutputData())
        print("X" + str(trainX.shape))
        print("Y" + str(trainY.shape))

        self.model.compile(optimizer='adam',
                           loss='sparse_categorical_crossentropy',
                           metrics=['accuracy'])

        self.model.fit(trainX,
                       trainY,
                       validation_split=0.1,
                       batch_size=100,
                       epochs=10,
                       shuffle=True,
                       callbacks=[self.checkpoint]
                       )
        self.exportNN()

    def getTrainingInputData(self):
        data = self.db_manager.getWeeklyInputs()
        for each in range(0, len(data)):
            temp_arr = []
            for each2 in range(0, len(data[each]) - 1):
                temp = []
                for val in data[each][each2]:
                    temp.append(val)
                temp_arr.append(temp)
            data[each] = temp_arr
        return data

    def getTrainingOutputData(self):
        data = self.db_manager.getWeeklyInputs()
        for each in range(0, len(data)):
            temp_arr = []

            for each2 in range(0, len(data[each])):
                expected = data[each][5]
                temp_arr.append(expected)
            data[each] = temp_arr

        output = []
        for this in range(0, len(data)):
            if data[this][0] == 0:
                tem = 0
                output.append(tem)
            if data[this][0] == 1:
                tem = 1
                output.append(tem)
            if data[this][0] == 2:
                tem = 2
                output.append(tem)
            if data[this][0] == 3:
                tem = 3
                output.append(tem)

        return output


nn = NeuralNetwork()

nn.train()

# test_loss, test_acc = model.evaluate(test, verbose=1)

# print('Test accuracy:', test_acc)
# predictions = model.predict(test)

# predictions[0]
